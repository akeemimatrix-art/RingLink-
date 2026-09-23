-- Seed categories for the RingLink Kampala MVP.
insert into public.categories (name, slug, icon_name, sort_order) values
  ('Plumbing', 'plumbing', 'plumbing', 10),
  ('Electrician', 'electrician', 'bolt', 20),
  ('Boda Boda', 'boda-boda', 'motorcycle', 30),
  ('Taxi', 'taxi', 'directions_car', 40),
  ('Delivery', 'delivery', 'local_shipping', 50),
  ('Primary Teacher', 'primary-teacher', 'school', 60),
  ('Secondary Teacher', 'secondary-teacher', 'school', 70),
  ('A-Level Teacher', 'a-level-teacher', 'school', 80),
  ('Tutor', 'tutor', 'school', 90),
  ('Mechanic', 'mechanic', 'directions_car', 100),
  ('Carpenter', 'carpenter', 'handyman', 110),
  ('Cleaner', 'cleaner', 'cleaning_services', 120),
  ('Painter', 'painter', 'format_paint', 130),
  ('Barber', 'barber', 'content_cut', 140),
  ('Hairdresser', 'hairdresser', 'face', 150),
  ('Makeup Artist', 'makeup-artist', 'face', 160),
  ('Phone Repair', 'phone-repair', 'phone_android', 170),
  ('Computer Repair', 'computer-repair', 'computer', 180),
  ('Photographer', 'photographer', 'photo_camera', 190),
  ('Accountant', 'accountant', 'calculate', 200),
  ('Lawyer', 'lawyer', 'gavel', 210),
  ('Event Planner', 'event-planner', 'event', 220),
  ('Car Wash', 'car-wash', 'local_car_wash', 230)
on conflict (slug) do update set
  name = excluded.name,
  icon_name = excluded.icon_name,
  sort_order = excluded.sort_order,
  is_active = true;

-- Teacher subject categories are represented as services under the education category.
-- Providers choose service names such as Mathematics, English, Physics, Chemistry, Biology, History, Geography, SST and Science.
