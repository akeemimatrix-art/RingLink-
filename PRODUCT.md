# RingLink Product Definition

## Simple product description

RingLink is a verified local service directory. A customer searches for a service, sees nearby providers, opens a professional profile, and calls or messages the provider.

The signature future feature is Ring:

1. Customer selects a category and describes the job.
2. Customer chooses a search radius.
3. Backend finds eligible providers who are verified, active, subscribed, available, and nearby.
4. A Ring participant record is created for each eligible provider.
5. The first provider whose acceptance reaches the database lock wins.
6. Other participants are marked cancelled.
7. The customer and winner get a conversation record.

## Account types

- Customer: discovers and contacts providers.
- Provider: offers one or more services and maintains professional information.
- Business: reserved for group/company management expansion.
- Admin: platform moderation and operational control.

## V1 pages

- Splash/configuration state
- Login/sign-up
- Home
- Search
- Category
- Provider profile
- RING creation
- RING status
- Calls/Ring history
- Chat
- Profile
- Provider profile setup
- Verification
- Subscription
- Saved locations
- Reviews
- Settings
- Admin dashboard

## UX direction

RingLink should feel like:

- LinkedIn for professional profiles and trust signals.
- WhatsApp for simple communication.
- Maps for location awareness.
- RingLink for the high-visibility RING action.

## V1 visual rules

- White/light background
- Dark text
- Green primary brand colour
- Rounded 16–20 px cards
- Large touch targets
- Clear verification chips
- RING is the signature action
- Avoid clutter and dense marketplace layouts

## Subscription model in code

- Individual: US$5/month
- Business/Group: US$9.99/month

The repository models subscriptions as pending/active/etc. The current app uses admin activation as a temporary bridge. A production payment provider should write status changes through a verified server/webhook path.
