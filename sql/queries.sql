-- =============================================================================
-- (c) Required SQL Queries for snickr
-- CS6083 Project #1 --- Spring 2026
--
-- Placeholders of the form :param are used for bind variables the application
-- would supply at runtime. To test interactively in psql, use \set, e.g.:
--   \set workspace_id 1
--   \set user_id      1
--   \set channel_id   1
-- Each query is wrapped in a self-test block that substitutes the sample-data
-- values so it can be run verbatim against the populated database.
-- =============================================================================

-- ===========================================================================
-- (1) Create a new user account (with email, name, nickname, password).
-- ===========================================================================
-- Production form (application supplies bind values):
--   INSERT INTO users (email, username, nickname, password_hash)
--   VALUES (:email, :username, :nickname, :password_hash)
--   RETURNING user_id;

-- Self-test against sample data: register a new user "Grace".
INSERT INTO users (email, username, nickname, password_hash)
VALUES ('grace@acme.com', 'grace', 'Grace', 'hash_grace')
RETURNING user_id;


-- ===========================================================================
-- (2) Create a new public channel inside a workspace by a particular user.
--     The user must be a member of the workspace; the guarded INSERT inserts
--     zero rows if the authorization check fails.
-- ===========================================================================
-- Production form:
--   INSERT INTO channels (workspace_id, name, type, created_by)
--   SELECT :workspace_id, :name, 'public', :user_id
--   WHERE EXISTS (
--       SELECT 1 FROM workspace_members
--       WHERE workspace_id = :workspace_id AND user_id = :user_id
--   )
--   RETURNING channel_id;
--   -- Then add the creator to the new channel:
--   INSERT INTO channel_members (channel_id, user_id)
--   VALUES (:new_channel_id, :user_id);

-- Self-test A: Alice (user_id=1, Acme member) creates #random -> should succeed.
-- Step 1: create the channel and note the returned channel_id.
INSERT INTO channels (workspace_id, name, type, created_by)
SELECT 1, '#random', 'public', 1
WHERE EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_id = 1 AND user_id = 1
)
RETURNING channel_id;

-- Step 2: using the returned channel_id from the previous statement, add Alice
-- as the first channel member. In this self-test, the returned channel_id is 6
-- because sample_data.sql inserts channels 1 through 5.
INSERT INTO channel_members (channel_id, user_id)
VALUES (6, 1);

-- Self-test B: Eve (user_id=5, NOT a member of Acme) tries to create in Acme
-- -> should insert 0 rows (authorization denied).
INSERT INTO channels (workspace_id, name, type, created_by)
SELECT 1, '#eve-unauthorized', 'public', 5
WHERE EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_id = 1 AND user_id = 5
)
RETURNING channel_id;


-- ===========================================================================
-- (3) For each workspace, list all current administrators.
-- ===========================================================================
SELECT w.workspace_id,
       w.name AS workspace,
       u.username AS administrator
FROM   workspaces w
JOIN   workspace_members wm ON wm.workspace_id = w.workspace_id
JOIN   users u              ON u.user_id       = wm.user_id
WHERE  wm.is_admin = TRUE
ORDER BY w.workspace_id, u.username;


-- ===========================================================================
-- (4) For each public channel in a given workspace, list the number of users
--     that were invited to join the channel more than 5 days ago and that
--     have not yet joined.
-- ===========================================================================
-- Production form parameterized by :workspace_id.
-- Self-test: workspace_id = 1 (Acme). Expected: #general -> 1, others -> 0.
SELECT c.channel_id,
       c.name,
       COUNT(ci.invitee_user_id) FILTER (WHERE cm.user_id IS NULL)
       AS stale_unjoined_invites
FROM   channels c
LEFT   JOIN channel_invitations ci
       ON ci.channel_id = c.channel_id
      AND ci.invited_at < CURRENT_TIMESTAMP - INTERVAL '5 days'
LEFT   JOIN channel_members cm
       ON cm.channel_id = ci.channel_id
      AND cm.user_id    = ci.invitee_user_id
WHERE  c.workspace_id = 1                      -- :workspace_id
  AND  c.type         = 'public'
GROUP BY c.channel_id, c.name
ORDER BY c.name;


-- ===========================================================================
-- (5) For a particular channel, list all messages in chronological order.
-- ===========================================================================
-- Self-test: channel_id = 1 (Acme #general).
SELECT m.message_id,
       m.posted_at,
       u.username,
       m.body
FROM   messages m
JOIN   users u ON u.user_id = m.sender_user_id
WHERE  m.channel_id = 1                        -- :channel_id
ORDER BY m.posted_at ASC, m.message_id ASC;


-- ===========================================================================
-- (6) For a particular user, list all messages they have posted in any channel.
-- ===========================================================================
-- Self-test: user_id = 1 (Alice), who has posted in multiple workspaces.
SELECT m.message_id,
       w.name   AS workspace,
       c.name   AS channel,
       m.posted_at,
       m.body
FROM   messages m
JOIN   channels   c ON c.channel_id   = m.channel_id
JOIN   workspaces w ON w.workspace_id = c.workspace_id
WHERE  m.sender_user_id = 1                    -- :user_id
ORDER BY m.posted_at DESC;


-- ===========================================================================
-- (7) For a particular user, list all messages accessible to that user that
--     contain the keyword "perpendicular" in the body.
--     Accessible = user is a member of BOTH the workspace and the channel
--     in which the message was posted.
-- ===========================================================================
-- Self-test A: user_id = 1 (Alice) -> sees BOTH "perpendicular" messages
--              (one in #general, one in private #hiring).
SELECT m.message_id,
       w.name AS workspace,
       c.name AS channel,
       u.username AS author,
       m.posted_at,
       m.body
FROM   messages m
JOIN   channels         c  ON c.channel_id    = m.channel_id
JOIN   workspaces       w  ON w.workspace_id  = c.workspace_id
JOIN   users            u  ON u.user_id       = m.sender_user_id
JOIN   channel_members  cm ON cm.channel_id   = c.channel_id
                          AND cm.user_id      = 1      -- :user_id
JOIN   workspace_members wm ON wm.workspace_id = w.workspace_id
                           AND wm.user_id      = 1      -- :user_id
WHERE  m.body ILIKE '%perpendicular%'
ORDER BY m.posted_at DESC;

-- Self-test B: user_id = 3 (Carol) -> sees ONLY the #general message
--              (Carol is not a member of private #hiring).
SELECT m.message_id,
       w.name AS workspace,
       c.name AS channel,
       u.username AS author,
       m.posted_at,
       m.body
FROM   messages m
JOIN   channels         c  ON c.channel_id    = m.channel_id
JOIN   workspaces       w  ON w.workspace_id  = c.workspace_id
JOIN   users            u  ON u.user_id       = m.sender_user_id
JOIN   channel_members  cm ON cm.channel_id   = c.channel_id
                          AND cm.user_id      = 3      -- :user_id
JOIN   workspace_members wm ON wm.workspace_id = w.workspace_id
                           AND wm.user_id      = 3      -- :user_id
WHERE  m.body ILIKE '%perpendicular%'
ORDER BY m.posted_at DESC;

-- Self-test C: user_id = 4 (Dave) -> sees NONE
--              (Dave has not joined #general, so even the public message
--              is inaccessible per the "channel membership required" rule).
SELECT m.message_id,
       w.name AS workspace,
       c.name AS channel,
       u.username AS author,
       m.posted_at,
       m.body
FROM   messages m
JOIN   channels         c  ON c.channel_id    = m.channel_id
JOIN   workspaces       w  ON w.workspace_id  = c.workspace_id
JOIN   users            u  ON u.user_id       = m.sender_user_id
JOIN   channel_members  cm ON cm.channel_id   = c.channel_id
                          AND cm.user_id      = 4      -- :user_id
JOIN   workspace_members wm ON wm.workspace_id = w.workspace_id
                           AND wm.user_id      = 4      -- :user_id
WHERE  m.body ILIKE '%perpendicular%'
ORDER BY m.posted_at DESC;
