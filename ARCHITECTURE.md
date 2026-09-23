# RingLink Architecture

## Frontend

Flutter Android application.

Main navigation:

- Home
- Calls
- RING
- Profile

## Backend

Supabase:

- PostgreSQL database
- PostGIS for nearby-distance search
- Auth
- Storage
- Realtime
- SQL functions/triggers

## Security principles

- No service-role key in the mobile app.
- RLS enabled on application tables.
- Verification documents live in a private bucket.
- Admin role cannot be self-assigned.
- Provider verification cannot be self-granted.
- Public directory visibility requires verified + available + subscribed provider.
- Ring winner is locked in a row-level transaction before participants are cancelled.

## Ring workflow

```text
Customer
  |
  | INSERT ring_request
  v
Postgres trigger
  |
  | find nearby eligible providers
  v
ring_participants
  |
  | provider accepts
  v
ring_acceptances
  |
  | BEFORE INSERT trigger + FOR UPDATE
  v
ring_requests.status = accepted
ring_requests.winner_provider_id = provider
  |
  +--> winner participant = accepted
  +--> other participants = cancelled
  +--> conversation created
```

## Real-time limitation of the MVP

The database workflow is real-time-capable, but a database subscription is not the same thing as a guaranteed incoming cellular/VoIP call. The production Ring Engine still needs a wake-up/push/telephony layer that delivers an incoming call UX on Android when the provider app is backgrounded or closed.

## Future scaling path

1. Add a production push provider and Android incoming-call UX.
2. Add a telephony/VoIP provider and call routing.
3. Move subscription/payment activation to signed server-side webhooks.
4. Add background location policies carefully.
5. Add caching/queues/Redis only when measured traffic requires it.
6. Add country-specific verification and payment adapters.
