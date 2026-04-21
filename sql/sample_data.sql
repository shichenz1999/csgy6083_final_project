-- =============================================================================
-- (d) Sample Data for snickr
-- Populates 6 users, 2 workspaces, 5 channels, 3 pending invitations,
-- and 13 messages.
-- Designed to exercise every query in queries.sql, including edge cases:
--   * Q4: stale (>5-day) unjoined invite vs. fresh (2-day) invite
--   * Q7: "perpendicular" message visible to some users but not others
-- All timestamps are computed relative to CURRENT_TIMESTAMP so the sample
-- remains meaningful whenever the script is run.
-- =============================================================================

BEGIN;

-- ---- Users -------------------------------------------------------------------
INSERT INTO users (user_id, email, username, nickname, password_hash, created_at) VALUES
    (1, 'alice@acme.com',   'alice', 'Alice',  'hash_alice', NOW() - INTERVAL '30 days'),
    (2, 'bob@acme.com',     'bob',   'Bob',    'hash_bob',   NOW() - INTERVAL '30 days'),
    (3, 'carol@acme.com',   'carol', 'Carol',  'hash_carol', NOW() - INTERVAL '25 days'),
    (4, 'dave@acme.com',    'dave',  'Dave',   'hash_dave',  NOW() - INTERVAL '20 days'),
    (5, 'eve@coop.org',     'eve',   'Eve',    'hash_eve',   NOW() - INTERVAL '30 days'),
    (6, 'frank@coop.org',   'frank', 'Frank',  'hash_frank', NOW() - INTERVAL '25 days');

-- Keep the sequence aligned with the manually assigned user_ids above.
SELECT setval(pg_get_serial_sequence('users', 'user_id'),
              (SELECT MAX(user_id) FROM users));

-- ---- Workspaces --------------------------------------------------------------
INSERT INTO workspaces (workspace_id, name, description, created_by, created_at) VALUES
    (1, 'Acme Co.',   'Acme Corporation internal workspace',  1, NOW() - INTERVAL '28 days'),
    (2, 'Coop Board', 'Building co-op board communications',  5, NOW() - INTERVAL '28 days');

SELECT setval(pg_get_serial_sequence('workspaces', 'workspace_id'),
              (SELECT MAX(workspace_id) FROM workspaces));

-- ---- Workspace membership ----------------------------------------------------
-- Acme: Alice & Bob are admins; Carol & Dave are regular members.
INSERT INTO workspace_members (workspace_id, user_id, is_admin, joined_at) VALUES
    (1, 1, TRUE,  NOW() - INTERVAL '28 days'),   -- Alice (admin, creator)
    (1, 2, TRUE,  NOW() - INTERVAL '27 days'),   -- Bob   (admin)
    (1, 3, FALSE, NOW() - INTERVAL '20 days'),   -- Carol
    (1, 4, FALSE, NOW() - INTERVAL '15 days'),   -- Dave
-- Coop Board: Eve admin; Frank & Alice members.
    (2, 5, TRUE,  NOW() - INTERVAL '28 days'),   -- Eve (admin, creator)
    (2, 6, FALSE, NOW() - INTERVAL '21 days'),   -- Frank
    (2, 1, FALSE, NOW() - INTERVAL '14 days');   -- Alice

-- ---- Channels ----------------------------------------------------------------
INSERT INTO channels (channel_id, workspace_id, name, type, created_by, created_at) VALUES
    -- Acme Co.
    (1, 1, '#general',       'public',  1, NOW() - INTERVAL '28 days'),
    (2, 1, '#hiring',        'private', 1, NOW() - INTERVAL '26 days'),
    (3, 1, 'dm-alice-carol', 'direct',  1, NOW() - INTERVAL '10 days'),
    -- Coop Board
    (4, 2, '#announcements', 'public',  5, NOW() - INTERVAL '28 days'),
    (5, 2, '#finance',       'private', 5, NOW() - INTERVAL '26 days');

SELECT setval(pg_get_serial_sequence('channels', 'channel_id'),
              (SELECT MAX(channel_id) FROM channels));

-- ---- Channel membership ------------------------------------------------------
INSERT INTO channel_members (channel_id, user_id, joined_at) VALUES
    -- Acme #general (public): everyone but Dave has joined.
    (1, 1, NOW() - INTERVAL '28 days'),   -- Alice
    (1, 2, NOW() - INTERVAL '27 days'),   -- Bob
    (1, 3, NOW() - INTERVAL '19 days'),   -- Carol
    -- Note: Dave is invited but has NOT joined (see invitations below, Q4).

    -- Acme #hiring (private): only Alice & Bob.
    (2, 1, NOW() - INTERVAL '26 days'),
    (2, 2, NOW() - INTERVAL '26 days'),

    -- Acme direct channel: Alice & Carol only.
    (3, 1, NOW() - INTERVAL '10 days'),
    (3, 3, NOW() - INTERVAL '10 days'),

    -- Coop #announcements: Eve, Frank, Alice.
    (4, 5, NOW() - INTERVAL '28 days'),
    (4, 6, NOW() - INTERVAL '20 days'),
    (4, 1, NOW() - INTERVAL '14 days'),

    -- Coop #finance (private): Eve & Frank.
    (5, 5, NOW() - INTERVAL '26 days'),
    (5, 6, NOW() - INTERVAL '18 days');

-- ---- Channel invitations -----------------------------------------------------
-- Two pending channel invites to Dave inside Acme:
--   * one to #general dated 7 days ago -> counted by Q4 (>5-day stale, unjoined)
--   * one to #hiring  dated 2 days ago -> ignored by Q4 (fresh)
INSERT INTO channel_invitations
       (channel_id, invitee_user_id, invited_by, invited_at, status) VALUES
    (1, 4, 2, NOW() - INTERVAL '7 days', 'pending'),   -- Bob invites Dave to Acme #general (STALE)
    (2, 4, 1, NOW() - INTERVAL '2 days', 'pending');   -- Alice invites Dave to Acme #hiring (FRESH)

-- ---- Workspace invitations ---------------------------------------------------
INSERT INTO workspace_invitations
       (workspace_id, invitee_user_id, invited_by, invited_at, status) VALUES
    (2, 4, 5, NOW() - INTERVAL '3 days', 'pending');   -- Eve invites Dave to Coop Board workspace

-- ---- Messages ----------------------------------------------------------------
-- Acme #general (4 msgs; exactly one mentions "perpendicular").
INSERT INTO messages (channel_id, sender_user_id, body, posted_at) VALUES
    (1, 1, 'Welcome to Acme #general!',                               NOW() - INTERVAL '6 days'),
    (1, 2, 'Standup notes will be posted here daily.',                NOW() - INTERVAL '4 days'),
    (1, 3, 'Quick geometry question: are these lines perpendicular?', NOW() - INTERVAL '2 days'),
    (1, 1, 'Let''s meet tomorrow at 10am.',                            NOW() - INTERVAL '1 days'),

-- Acme #hiring (2 msgs; one mentions "perpendicular" but is inaccessible to Carol).
    (2, 1, 'Candidate feedback for the backend role.',                      NOW() - INTERVAL '5 days'),
    (2, 2, 'Their system-design answer had two perpendicular approaches.',  NOW() - INTERVAL '3 days'),

-- Acme direct channel (2 msgs, Alice & Carol).
    (3, 1, 'Hey Carol, got a minute?',   NOW() - INTERVAL '9 days'),
    (3, 3, 'Sure, what''s up?',          NOW() - INTERVAL '9 days'),

-- Coop #announcements (3 msgs; none mention "perpendicular").
    (4, 5, 'Board meeting next Tuesday at 7pm.',                 NOW() - INTERVAL '8 days'),
    (4, 6, 'Reminder to pay monthly maintenance by the 15th.',   NOW() - INTERVAL '5 days'),
    (4, 1, 'Could someone share last month''s minutes?',         NOW() - INTERVAL '3 days'),

-- Coop #finance (2 msgs).
    (5, 5, 'Q1 budget draft is attached.',   NOW() - INTERVAL '7 days'),
    (5, 6, 'I''ll bring the reserve-fund numbers to the next meeting.', NOW() - INTERVAL '2 days');

COMMIT;

-- Quick sanity checks (uncomment to inspect):
-- SELECT COUNT(*) FROM users;             -- 6
-- SELECT COUNT(*) FROM workspaces;        -- 2
-- SELECT COUNT(*) FROM channels;          -- 5
-- SELECT COUNT(*) FROM messages;          -- 13
-- SELECT COUNT(*) FROM channel_invitations WHERE status='pending';  -- 2
