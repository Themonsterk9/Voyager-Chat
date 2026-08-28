const supabase = require('../config/supabase');
const crypto = require('crypto');

// In-memory fallback stores for high performance & offline reliability
const inMemoryProfiles = new Map();
const inMemoryConversations = new Map();
const inMemoryMembers = new Map(); // conversationId -> Set(userIds)
const inMemoryMessages = new Map(); // conversationId -> Array of messages

class ChatService {
  // --- USER PROFILES ---
  async searchUsers(query, excludeUserId) {
    const q = (query || '').trim().toLowerCase();
    if (!q) return [];

    // Attempt Supabase search first if configured
    if (supabase) {
      try {
        let req = supabase
          .from('profiles')
          .select('id, username, display_name, avatar_url, email, auth_provider, status, last_seen, created_at, updated_at')
          .or(`username.ilike.%${q}%,display_name.ilike.%${q}%,email.ilike.%${q}%`)
          .limit(20);

        if (excludeUserId) {
          req = req.neq('id', excludeUserId);
        }

        const { data, error } = await req;
        if (!error && Array.isArray(data) && data.length > 0) {
          // Cache results in memory
          for (const p of data) {
            inMemoryProfiles.set(p.id, p);
          }
          return data.map(this._mapProfile);
        }
      } catch (err) {
        console.warn('Supabase searchUsers fallback to memory:', err.message);
      }
    }

    // In-memory search fallback
    const results = [];
    for (const [id, profile] of inMemoryProfiles.entries()) {
      if (excludeUserId && id === excludeUserId) continue;
      const name = (profile.display_name || '').toLowerCase();
      const username = (profile.username || '').toLowerCase();
      const email = (profile.email || '').toLowerCase();
      if (name.includes(q) || username.includes(q) || email.includes(q)) {
        results.push(this._mapProfile(profile));
      }
    }
    return results;
  }

  async getUserProfile(userId) {
    if (!userId) return null;

    if (supabase) {
      try {
        const { data } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
        if (data) {
          inMemoryProfiles.set(userId, data);
          return this._mapProfile(data);
        }
      } catch (_) {}
    }

    const cached = inMemoryProfiles.get(userId);
    return cached ? this._mapProfile(cached) : null;
  }

  async upsertProfile(profileData) {
    if (!profileData || !profileData.id) return null;
    const now = new Date().toISOString();
    const profile = {
      id: profileData.id,
      email: profileData.email || null,
      display_name: profileData.displayName || profileData.display_name || 'Voyager User',
      username: profileData.username || (profileData.email ? profileData.email.split('@')[0] : `user_${profileData.id.slice(-6)}`),
      avatar_url: profileData.avatarUrl || profileData.avatar_url || null,
      auth_provider: profileData.authProvider || profileData.auth_provider || 'email',
      status: profileData.status || 'online',
      last_seen: now,
      created_at: profileData.createdAt || profileData.created_at || now,
      updated_at: now,
    };

    inMemoryProfiles.set(profile.id, profile);

    if (supabase) {
      try {
        await supabase.from('profiles').upsert(profile);
      } catch (err) {
        console.warn('Supabase profile upsert warning:', err.message);
      }
    }
    return this._mapProfile(profile);
  }

  // --- CONVERSATIONS ---
  async getUserConversations(userId) {
    if (!userId) return [];

    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('conversation_members')
          .select(`
            conversation_id,
            conversations (
              id,
              type,
              name,
              created_by,
              created_at,
              updated_at,
              avatar_url,
              invite_code
            )
          `)
          .eq('user_id', userId);

        if (!error && Array.isArray(data)) {
          const list = [];
          for (const row of data) {
            if (row.conversations) {
              list.push(this._mapConversation(row.conversations));
            }
          }
          return list;
        }
      } catch (_) {}
    }

    // In-memory fallback
    const list = [];
    for (const [convId, members] of inMemoryMembers.entries()) {
      if (members.has(userId)) {
        const conv = inMemoryConversations.get(convId);
        if (conv) list.push(this._mapConversation(conv));
      }
    }

    // Sort by updated_at descending
    list.sort((a, b) => new Date(b.updatedAt || b.createdAt) - new Date(a.updatedAt || a.createdAt));
    return list;
  }

  async findDirectConversation(user1Id, user2Id) {
    if (!user1Id || !user2Id) return null;

    if (supabase) {
      try {
        const { data: myMemberships } = await supabase
          .from('conversation_members')
          .select(`
            conversation_id,
            conversations!inner (
              id, type, name, created_by, created_at, updated_at, avatar_url, invite_code
            )
          `)
          .eq('user_id', user1Id)
          .eq('conversations.type', 'direct');

        if (Array.isArray(myMemberships)) {
          for (const row of myMemberships) {
            const convId = row.conversation_id;
            const { data: otherMembers } = await supabase
              .from('conversation_members')
              .select('user_id')
              .eq('conversation_id', convId)
              .eq('user_id', user2Id);

            if (Array.isArray(otherMembers) && otherMembers.length > 0) {
              return this._mapConversation(row.conversations);
            }
          }
        }
      } catch (_) {}
    }

    // In-memory fallback search
    for (const [convId, members] of inMemoryMembers.entries()) {
      const conv = inMemoryConversations.get(convId);
      if (conv && conv.type === 'direct' && members.has(user1Id) && members.has(user2Id)) {
        return this._mapConversation(conv);
      }
    }
    return null;
  }

  async createDirectConversation(user1Id, user2Id) {
    if (!user1Id || !user2Id) {
      throw new Error('Both user IDs are required to start a direct conversation.');
    }
    if (user1Id === user2Id) {
      throw new Error('You cannot start a conversation with yourself.');
    }

    const existing = await this.findDirectConversation(user1Id, user2Id);
    if (existing) {
      return existing;
    }

    const now = new Date().toISOString();
    const convId = `conv_${crypto.randomBytes(12).toString('hex')}`;
    const inviteCode = crypto.randomBytes(4).toString('hex');

    const conversationData = {
      id: convId,
      type: 'direct',
      name: null,
      created_by: user1Id,
      created_at: now,
      updated_at: now,
      avatar_url: null,
      invite_code: inviteCode,
    };

    inMemoryConversations.set(convId, conversationData);
    inMemoryMembers.set(convId, new Set([user1Id, user2Id]));
    inMemoryMessages.set(convId, []);

    if (supabase) {
      try {
        await supabase.from('conversations').insert(conversationData);
        await supabase.from('conversation_members').insert([
          { conversation_id: convId, user_id: user1Id, role: 'owner' },
          { conversation_id: convId, user_id: user2Id, role: 'member' },
        ]);
      } catch (err) {
        console.warn('Supabase createDirectConversation warning:', err.message);
      }
    }

    return this._mapConversation(conversationData);
  }

  async isConversationMember(conversationId, userId) {
    if (!conversationId || !userId) return false;

    if (supabase) {
      try {
        const { data } = await supabase
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .maybeSingle();
        if (data) return true;
      } catch (_) {}
    }

    const members = inMemoryMembers.get(conversationId);
    return members ? members.has(userId) : false;
  }

  // --- MESSAGES ---
  async getConversationMessages(conversationId, limit = 50, offset = 0) {
    if (!conversationId) return [];

    if (supabase) {
      try {
        const { data, error } = await supabase
          .from('messages')
          .select('*')
          .eq('conversation_id', conversationId)
          .order('created_at', { ascending: true })
          .range(offset, offset + limit - 1);

        if (!error && Array.isArray(data) && data.length > 0) {
          return data.map(this._mapMessage);
        }
      } catch (_) {}
    }

    const messages = inMemoryMessages.get(conversationId) || [];
    return messages.map(this._mapMessage);
  }

  async createMessage({ conversationId, senderId, content, messageType = 'text', clientMessageId, replyToMessageId }) {
    if (!conversationId || !senderId) {
      throw new Error('Conversation ID and Sender ID are required.');
    }

    const isMember = await this.isConversationMember(conversationId, senderId);
    if (!isMember) {
      throw new Error('Unauthorized: Sender is not a member of this conversation.');
    }

    const now = new Date().toISOString();
    const msgId = `msg_${crypto.randomBytes(12).toString('hex')}`;

    const messageData = {
      id: msgId,
      conversation_id: conversationId,
      sender_id: senderId,
      content: content || '',
      message_type: messageType,
      client_message_id: clientMessageId || msgId,
      reply_to_message_id: replyToMessageId || null,
      created_at: now,
      edited_at: null,
      deleted_at: null,
    };

    // Store in memory
    if (!inMemoryMessages.has(conversationId)) {
      inMemoryMessages.set(conversationId, []);
    }
    inMemoryMessages.get(conversationId).push(messageData);

    // Update conversation timestamp
    const conv = inMemoryConversations.get(conversationId);
    if (conv) {
      conv.updated_at = now;
    }

    if (supabase) {
      try {
        await supabase.from('messages').insert(messageData);
        await supabase
          .from('conversations')
          .update({ updated_at: now })
          .eq('id', conversationId);
      } catch (err) {
        console.warn('Supabase createMessage warning:', err.message);
      }
    }

    return this._mapMessage(messageData);
  }

  // Helpers to ensure clean JSON output
  _mapProfile(row) {
    return {
      id: row.id,
      email: row.email || null,
      displayName: row.display_name || row.displayName || null,
      username: row.username || null,
      avatarUrl: row.avatar_url || row.avatarUrl || null,
      authProvider: row.auth_provider || row.authProvider || 'email',
      status: row.status || 'online',
      lastSeen: row.last_seen || row.lastSeen || null,
      createdAt: row.created_at || row.createdAt || null,
      updatedAt: row.updated_at || row.updatedAt || null,
    };
  }

  _mapConversation(row) {
    return {
      id: row.id,
      type: row.type || 'direct',
      name: row.name || null,
      createdBy: row.created_by || row.createdBy || null,
      createdAt: row.created_at || row.createdAt || null,
      updatedAt: row.updated_at || row.updatedAt || null,
      avatarUrl: row.avatar_url || row.avatarUrl || null,
      inviteCode: row.invite_code || row.inviteCode || null,
    };
  }

  _mapMessage(row) {
    return {
      id: row.id,
      conversationId: row.conversation_id || row.conversationId,
      senderId: row.sender_id || row.senderId,
      content: row.content || null,
      messageType: row.message_type || row.messageType || 'text',
      clientMessageId: row.client_message_id || row.clientMessageId || null,
      replyToMessageId: row.reply_to_message_id || row.replyToMessageId || null,
      createdAt: row.created_at || row.createdAt || null,
      editedAt: row.edited_at || row.editedAt || null,
      deletedAt: row.deleted_at || row.deletedAt || null,
    };
  }
}

module.exports = new ChatService();
