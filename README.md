# CraftVerse Next.js

JavaScript Next.js marketplace connected to Supabase. Start with `npm install`, copy `.env.example` to `.env.local`, set the Supabase project URL and anon key, then run `npm run dev`. The browser uses the public anon/publishable key; row-level security protects application data.

The app migrates the customer, seller, and admin pages from both supplied folders into Next.js routes. Customer features include product search/filter/sort, product details and reviews, wishlists, carts with personalization, demo checkout, order tracking, and creator questions. Seller features include shop profiles, listing uploads and management, order status updates, sales reports, and replies to customer questions. Admin features include account blocking and seller verification, product moderation, order status management, review moderation, analytics and CSV export, category management, and audience-targeted announcements.

Before first use, run the latest `supabase/setup.sql` in the Supabase SQL editor. The setup script is repeatable for this app's schema updates. Promote an account to admin using the SQL comment at the end of `supabase/setup.sql`.

For a populated presentation, create the seller (`rupas.00657@gmai.com`) and customer (`rudramanger2006@gmail.com`) in Supabase Auth, then run `supabase/demo_seed.sql`. It adds products, seller/shop data, example orders, reviews, questions, cart and wishlist entries, and announcements. The products use images shipped in `public/images`; the demo seed is safe to run more than once.

For deployment, set the production domain as the Supabase Auth Site URL and add it to the allowed redirect URLs (include `/reset-password`). Configure email confirmation and password recovery delivery in Supabase Auth. Keep the anon/publishable key in `NEXT_PUBLIC_SUPABASE_ANON_KEY`; never put a Supabase service-role key in a `NEXT_PUBLIC_` variable or browser code. Checkout currently records demo orders only; payment collection, seller payouts, and email delivery require separate integrations.
