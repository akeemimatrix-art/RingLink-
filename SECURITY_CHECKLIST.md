# RingLink security checklist

## Secrets

- Never commit `config/dev.json`.
- Never put a Supabase service-role/secret key in Flutter code.
- Never commit Android keystores, passwords or signing files.

## Database

- Keep RLS enabled on every client-accessible table.
- Keep security-definer functions on an explicit `search_path`.
- Keep admin role changes manual and controlled.
- Never let clients write verification flags directly.
- Keep verification documents in the private storage bucket.
- Keep contact phone numbers behind the approved contact RPC where a Ring creates a connection.

## Ring Engine

- Acceptance is serialized by locking the Ring row with `FOR UPDATE`.
- A provider must be a Ring participant and still be in `ringing` state to accept.
- Once accepted, all other participants are cancelled in the same transaction.
- A Ring expires after its deadline and cannot be accepted afterward.

## Mobile

- Request location only when needed.
- Explain why location is needed.
- Do not log access tokens or verification documents.
- Treat all remote data as untrusted input.

## Production review still required

- Threat-model the final payment integration.
- Add rate limits/abuse controls for sign-up, Ring creation and messaging.
- Add server-side moderation and fraud monitoring as usage grows.
- Add real push/VoIP infrastructure before claiming true simultaneous incoming phone-like Rings.
- Complete a Google Play Data Safety review against the final production configuration.
