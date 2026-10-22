-- CraftVerse schema for Supabase. Run in the Supabase SQL editor on a new project.
create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('customer','seller','admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.product_status as enum ('pending','approved','rejected');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null default '',
  role public.app_role not null default 'customer',
  shop_name text not null default '',
  bio text not null default '',
  seller_name text not null default '',
  phone text not null default '',
  city text not null default '',
  seller_description text not null default '',
  craft_category text not null default '',
  shop_address text not null default '',
  is_public boolean not null default true,
  avatar_url text,
  seller_verified boolean not null default false,
  blocked boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare requested_role text;
begin
  requested_role := coalesce(new.raw_user_meta_data->>'role','customer');
  insert into public.profiles(id,email,full_name,seller_name,role,shop_name)
  values(new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name',''), coalesce(new.raw_user_meta_data->>'full_name',''),
    case when requested_role='seller' then 'seller'::public.app_role else 'customer'::public.app_role end,
    coalesce(new.raw_user_meta_data->>'shop_name',''))
  on conflict(id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin' and not p.blocked);
$$;
create or replace function public.is_active_user() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles p where p.id = auth.uid() and not p.blocked);
$$;
create or replace function public.is_seller() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='seller' and not p.blocked);
$$;
create or replace function public.can_update_profile(target_id uuid, target_role public.app_role, target_verified boolean, target_blocked boolean) returns boolean
language sql stable security definer set search_path = '' as $$
 select public.is_admin() or exists(
  select 1 from public.profiles p where p.id=auth.uid() and p.id=target_id
   and (p.role=target_role or (p.role='customer' and target_role='seller'))
   and p.seller_verified=target_verified and p.blocked=target_blocked
 );
$$;

create table if not exists public.categories (
 id uuid primary key default gen_random_uuid(), name text not null unique, slug text not null unique,
 created_at timestamptz not null default now()
);
create table if not exists public.products (
 id uuid primary key default gen_random_uuid(), seller_id uuid references public.profiles(id) on delete set null,
 name text not null, description text not null default '', category text not null,
 price numeric(12,2) not null check(price >= 0), stock integer not null default 0 check(stock >= 0),
 image_url text, image_name text, status public.product_status not null default 'pending',
 materials text not null default '', tags text[] not null default '{}',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create or replace function public.keep_product_moderation_status() returns trigger
language plpgsql set search_path = '' as $$
begin
 if not public.is_admin() then new.status := old.status; end if;
 return new;
end; $$;
drop trigger if exists keep_product_moderation_status on public.products;
create trigger keep_product_moderation_status before update on public.products
for each row execute function public.keep_product_moderation_status();
create table if not exists public.cart_items (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete cascade, quantity integer not null check(quantity > 0),
 customisation text not null default '',
 created_at timestamptz not null default now(), unique(user_id,product_id,customisation)
);
create table if not exists public.wishlists (
 user_id uuid not null references public.profiles(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete cascade, created_at timestamptz not null default now(),
 primary key(user_id,product_id)
);
create table if not exists public.orders (
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.profiles(id),
 status text not null default 'placed' check(status in ('placed','processing','shipped','delivered','cancelled','refunded','disputed')),
 payment_method text not null default 'cod' check(payment_method in ('cod','demo')),
 payment_status text not null default 'not_processed', subtotal numeric(12,2) not null,
 shipping numeric(12,2) not null default 0, total numeric(12,2) not null,
 shipping_details jsonb not null, created_at timestamptz not null default now()
);
create table if not exists public.order_items (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null, product_name text not null,
 image_url text, unit_price numeric(12,2) not null, quantity integer not null check(quantity > 0),
 customisation text not null default '',
 created_at timestamptz not null default now()
);
create or replace function public.seller_owns_order(target_order uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.order_items oi join public.products p on p.id=oi.product_id where oi.order_id=target_order and p.seller_id=auth.uid());
$$;
create table if not exists public.reviews (
 id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id) on delete cascade,
 customer_id uuid not null references public.profiles(id) on delete cascade,
 rating integer not null check(rating between 1 and 5), title text not null default '',
 reviewer_name text not null default '', comment text not null default '', reported boolean not null default false,
 flagged boolean not null default false, status text not null default 'published' check(status in ('published','hidden')),
 created_at timestamptz not null default now()
);
create or replace function public.admin_update_review(review_id uuid, review_status text, is_flagged boolean, is_reported boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not public.is_admin() then raise exception 'Administrator access required'; end if;
 if review_status not in ('published','hidden') then raise exception 'Invalid review status'; end if;
 update public.reviews set status=review_status, flagged=is_flagged, reported=is_reported where id=review_id;
end; $$;
create table if not exists public.customer_queries (
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.profiles(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null,
  order_id uuid references public.orders(id) on delete set null,
 product_name text not null default '', message text not null, response text, status text not null default 'open',
 created_at timestamptz not null default now(), responded_at timestamptz
);
create table if not exists public.announcements (
 id uuid primary key default gen_random_uuid(), author_id uuid references public.profiles(id) on delete set null,
 type text not null default 'Store announcement',
 title text not null, message text not null, audience text not null default 'everyone'
 check(audience in ('everyone','customers','sellers')), created_at timestamptz not null default now()
);
alter table public.announcements add column if not exists type text not null default 'Store announcement';
-- Keep setup repeatable when refreshing a project created from an earlier setup.sql revision.
alter table public.profiles add column if not exists seller_name text not null default '';
alter table public.profiles add column if not exists phone text not null default '';
alter table public.profiles add column if not exists city text not null default '';
alter table public.profiles add column if not exists seller_description text not null default '';
alter table public.profiles add column if not exists craft_category text not null default '';
alter table public.profiles add column if not exists shop_address text not null default '';
alter table public.profiles add column if not exists is_public boolean not null default true;
alter table public.profiles add column if not exists avatar_url text;
alter table public.products add column if not exists materials text not null default '';
alter table public.products add column if not exists tags text[] not null default '{}';
alter table public.cart_items add column if not exists customisation text not null default '';
alter table public.cart_items drop constraint if exists cart_items_user_id_product_id_key;
create unique index if not exists cart_items_user_product_customisation_key on public.cart_items(user_id,product_id,customisation);
alter table public.order_items add column if not exists customisation text not null default '';
alter table public.reviews add column if not exists title text not null default '';
alter table public.reviews add column if not exists reviewer_name text not null default '';
alter table public.reviews add column if not exists reported boolean not null default false;
alter table public.reviews drop constraint if exists reviews_product_id_customer_id_key;
alter table public.customer_queries add column if not exists product_id uuid references public.products(id) on delete set null;
alter table public.customer_queries add column if not exists order_id uuid references public.orders(id) on delete set null;
create index if not exists products_status_category_idx on public.products(status,category);
create index if not exists orders_customer_date_idx on public.orders(customer_id,created_at desc);
create index if not exists order_items_order_idx on public.order_items(order_id);
create index if not exists queries_customer_idx on public.customer_queries(customer_id,created_at desc);

-- Totals and unit prices are derived from database records, then stock is decremented in one transaction.
create or replace function public.place_order(shipping_details jsonb, payment_method text default 'cod')
returns uuid language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); item record; new_order uuid; sub numeric(12,2) := 0; shipping_fee numeric(12,2); total_qty integer := 0;
begin
 if uid is null or not public.is_active_user() then raise exception 'Sign in with an active account to place an order'; end if;
 if payment_method is null or payment_method not in ('cod','demo') then raise exception 'Unsupported payment method'; end if;
 if jsonb_typeof(shipping_details) is distinct from 'object' then raise exception 'Delivery information is required'; end if;
 if coalesce(trim(shipping_details->>'full_name'),'') = '' or coalesce(trim(shipping_details->>'email'),'') = ''
   or coalesce(trim(shipping_details->>'phone'),'') = '' or coalesce(trim(shipping_details->>'address'),'') = ''
   or coalesce(trim(shipping_details->>'city'),'') = '' or coalesce(trim(shipping_details->>'state'),'') = ''
   or coalesce(trim(shipping_details->>'postal_code'),'') = '' then raise exception 'Complete all required delivery details'; end if;
 if (shipping_details->>'postal_code') !~ '^[0-9]{6}$' then raise exception 'Enter a valid six-digit PIN code'; end if;
 if length(coalesce(shipping_details->>'notes','')) > 500 then raise exception 'Order notes are too long'; end if;
 perform 1 from public.cart_items where user_id=uid;
 if not found then raise exception 'Your cart is empty'; end if;
 if exists(select 1 from public.cart_items c join public.products p on p.id=c.product_id where c.user_id=uid and p.status<>'approved') then
   raise exception 'One or more items in your cart are no longer available';
 end if;
 for item in select c.product_id,c.quantity,c.customisation,p.name,p.price,p.stock,p.image_url
   from public.cart_items c join public.products p on p.id=c.product_id
   where c.user_id=uid and p.status='approved' order by p.id for update of p
 loop
   if item.stock < item.quantity then raise exception 'Insufficient stock for %', item.name; end if;
   sub := sub + item.price * item.quantity;
   total_qty := total_qty + item.quantity;
 end loop;
 if total_qty = 0 then raise exception 'No available products in your cart'; end if;
 shipping_fee := case when sub >= 999 then 0 else 49 end;
 insert into public.orders(customer_id,payment_method,payment_status,subtotal,shipping,total,shipping_details)
 values(uid,payment_method,'not_processed',sub,shipping_fee,sub+shipping_fee,shipping_details) returning id into new_order;
 for item in select c.product_id,c.quantity,c.customisation,p.name,p.price,p.stock,p.image_url
   from public.cart_items c join public.products p on p.id=c.product_id
   where c.user_id=uid and p.status='approved' order by p.id for update of p
 loop
   update public.products set stock=stock-item.quantity,updated_at=now() where id=item.product_id;
   insert into public.order_items(order_id,product_id,product_name,image_url,unit_price,quantity,customisation)
   values(new_order,item.product_id,item.name,item.image_url,item.price,item.quantity,item.customisation);
 end loop;
 delete from public.cart_items where user_id=uid;
 return new_order;
end; $$;
revoke all on function public.place_order(jsonb,text) from public;
grant execute on function public.place_order(jsonb,text) to authenticated;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.cart_items enable row level security;
alter table public.wishlists enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.reviews enable row level security;
alter table public.customer_queries enable row level security;
alter table public.announcements enable row level security;

drop policy if exists "profiles visible to owner or admin" on public.profiles;
create policy "profiles visible to owner or admin" on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
drop policy if exists "public reads visible seller profile fields" on public.profiles;
create policy "public reads visible seller profile fields" on public.profiles for select using(role='seller' and is_public);
drop policy if exists "users update own safe profile fields" on public.profiles;
create policy "users update own safe profile fields" on public.profiles for update to authenticated using(id=auth.uid() or public.is_admin()) with check(public.can_update_profile(id,role,seller_verified,blocked));
revoke update on public.profiles from authenticated;
grant update(full_name,shop_name,bio,role,seller_verified,blocked,seller_name,phone,city,seller_description,craft_category,shop_address,is_public,avatar_url) on public.profiles to authenticated;
drop policy if exists "categories public read" on public.categories;
create policy "categories public read" on public.categories for select using(true);
drop policy if exists "admin manages categories" on public.categories;
create policy "admin manages categories" on public.categories for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "approved products public read" on public.products;
create policy "approved products public read" on public.products for select using(status='approved' or seller_id=auth.uid() or public.is_admin());
drop policy if exists "sellers create own products" on public.products;
create policy "sellers create own products" on public.products for insert to authenticated with check(seller_id=auth.uid() and public.is_active_user() and (select role from public.profiles where id=auth.uid())='seller' and status='pending');
drop policy if exists "sellers update own products" on public.products;
create policy "sellers update own products" on public.products for update to authenticated using((seller_id=auth.uid() and public.is_active_user()) or public.is_admin()) with check((seller_id=auth.uid() and public.is_active_user()) or public.is_admin());
drop policy if exists "sellers remove own products" on public.products;
create policy "sellers remove own products" on public.products for delete to authenticated using(seller_id=auth.uid() or public.is_admin());
drop policy if exists "users manage own cart" on public.cart_items;
create policy "users manage own cart" on public.cart_items for all to authenticated using(user_id=auth.uid() and public.is_active_user()) with check(user_id=auth.uid() and public.is_active_user());
drop policy if exists "users manage own wishlist" on public.wishlists;
create policy "users manage own wishlist" on public.wishlists for all to authenticated using(user_id=auth.uid() and public.is_active_user()) with check(user_id=auth.uid() and public.is_active_user());
drop policy if exists "customers admin and relevant sellers read orders" on public.orders;
drop policy if exists "customers and admin read orders" on public.orders;
create policy "customers admin and relevant sellers read orders" on public.orders for select to authenticated using(customer_id=auth.uid() or public.is_admin() or public.seller_owns_order(id));
drop policy if exists "admin updates orders" on public.orders;
create policy "admin updates orders" on public.orders for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "sellers update statuses for own orders" on public.orders;
create policy "sellers update statuses for own orders" on public.orders for update to authenticated using(public.seller_owns_order(id) and public.is_active_user()) with check(public.seller_owns_order(id) and status in ('processing','shipped','delivered'));
drop policy if exists "customers admins and sellers read order items" on public.order_items;
drop policy if exists "customers and admin read order items" on public.order_items;
create policy "customers admins and sellers read order items" on public.order_items for select to authenticated using(public.is_admin() or exists(select 1 from public.orders o where o.id=order_id and o.customer_id=auth.uid()) or exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid()));
drop policy if exists "published reviews public read" on public.reviews;
create policy "published reviews public read" on public.reviews for select using(status='published' or customer_id=auth.uid() or public.is_admin());
drop policy if exists "customers create own reviews" on public.reviews;
create policy "customers create own reviews" on public.reviews for insert to authenticated with check(customer_id=auth.uid() and public.is_active_user() and status='published' and not flagged and not reported);
drop policy if exists "owners and admins manage reviews" on public.reviews;
create policy "owners and admins manage reviews" on public.reviews for delete to authenticated using(customer_id=auth.uid() or public.is_admin());
drop policy if exists "admin updates reviews" on public.reviews;
create policy "admin updates reviews" on public.reviews for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "customers report reviews" on public.reviews;
create policy "customers report reviews" on public.reviews for update to authenticated using(customer_id=auth.uid() and public.is_active_user()) with check(customer_id=auth.uid() and public.is_active_user());
revoke update on public.reviews from authenticated;
grant update(reported) on public.reviews to authenticated;
revoke insert on public.reviews from authenticated;
grant insert(product_id,customer_id,rating,title,reviewer_name,comment) on public.reviews to authenticated;
revoke all on function public.admin_update_review(uuid,text,boolean,boolean) from public;
grant execute on function public.admin_update_review(uuid,text,boolean,boolean) to authenticated;
drop policy if exists "customers sellers and admin read queries" on public.customer_queries;
drop policy if exists "customers and admin read queries" on public.customer_queries;
create policy "customers sellers and admin read queries" on public.customer_queries for select to authenticated using(customer_id=auth.uid() or public.is_admin() or exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid()));
drop policy if exists "customers create own queries" on public.customer_queries;
create policy "customers create own queries" on public.customer_queries for insert to authenticated with check(customer_id=auth.uid() and public.is_active_user());
drop policy if exists "admin responds to queries" on public.customer_queries;
create policy "admin responds to queries" on public.customer_queries for update to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists "sellers respond to questions on their products" on public.customer_queries;
create policy "sellers respond to questions on their products" on public.customer_queries for update to authenticated using(exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid())) with check(exists(select 1 from public.products p where p.id=product_id and p.seller_id=auth.uid()));
revoke update on public.customer_queries from authenticated;
grant update(response,status,responded_at) on public.customer_queries to authenticated;
drop policy if exists "announcements public read" on public.announcements;
create policy "announcements public read" on public.announcements for select using(true);
drop policy if exists "admin manages announcements" on public.announcements;
create policy "admin manages announcements" on public.announcements for all to authenticated using(public.is_admin()) with check(public.is_admin());

grant select on public.products,public.categories,public.announcements to anon,authenticated;
grant select,insert,update,delete on public.profiles,public.cart_items,public.wishlists,public.products,public.reviews,public.customer_queries,public.categories,public.announcements to authenticated;
grant select(full_name,shop_name,bio,seller_name,city,seller_description,craft_category,avatar_url,role,is_public) on public.profiles to anon,authenticated;
grant select on public.orders to authenticated;
grant update(status) on public.orders to authenticated;
grant select on public.order_items to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "public reads product images" on storage.objects;
create policy "public reads product images" on storage.objects for select using(bucket_id='product-images');
drop policy if exists "sellers upload product images to own folder" on storage.objects;
create policy "sellers upload product images to own folder" on storage.objects for insert to authenticated with check(bucket_id='product-images' and (storage.foldername(name))[1]=auth.uid()::text and public.is_seller());
drop policy if exists "sellers update own product images" on storage.objects;
create policy "sellers update own product images" on storage.objects for update to authenticated using(bucket_id='product-images' and (storage.foldername(name))[1]=auth.uid()::text) with check(bucket_id='product-images' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "sellers delete own product images" on storage.objects;
create policy "sellers delete own product images" on storage.objects for delete to authenticated using(bucket_id='product-images' and (storage.foldername(name))[1]=auth.uid()::text);

insert into public.categories(name,slug) values
 ('Jewellery','jewellery'),('Macramé','macrame'),('Home Décor','home-decor'),('Gifts','gifts'),('Accessories','accessories'),('Art & Paintings','art-paintings'),('Paper Crafts','paper-crafts')
on conflict(slug) do nothing;

-- Promoting an admin: first sign up normally, then replace the email and run this statement.
-- update public.profiles set role='admin' where email='YOUR_ADMIN_EMAIL';
