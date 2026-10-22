-- CraftVerse presentation data. Run setup.sql first.
-- Create these Supabase Auth users before running this file:
--   Seller: rupas.00657@gmai.com
--   Customer: rudramanger2006@gmail.com
-- Use passwords you can share during the presentation. This script promotes the seller account
-- and places example orders, reviews, questions, wishlist items, and cart items on the customer account.
-- It replaces the nine starter products from older setup.sql versions. It is safe to run repeatedly.

do $$
declare
  seller_id uuid;
  customer_id uuid;
  customer_email text;
begin
  select id into seller_id from auth.users where lower(email) = 'rupas.00657@gmai.com' order by created_at desc limit 1;
  select id, email into customer_id, customer_email from auth.users where lower(email) = 'rudramanger2006@gmail.com' order by created_at desc limit 1;

  if seller_id is null then raise exception 'No Supabase Auth user found for rupas.00657@gmai.com. Check the email spelling in supabase/demo_seed.sql and confirm the user exists.'; end if;
  if customer_id is null then raise exception 'No Supabase Auth user found for rudramanger2006@gmail.com. Check that the user exists in Supabase Auth.'; end if;

  update public.profiles set
    role='seller', full_name='Aarav Mehta', seller_name='Aarav Mehta', shop_name='Aaranya Handmade',
    bio='Small-batch crafts made with patience and a deep love for natural materials.',
    seller_description='Aaranya is a family-run studio in Jaipur creating thoughtful home décor and accessories by hand. Each piece is made slowly, with natural fibers, local materials, and plenty of care.',
    craft_category='Home décor, macramé and accessories', city='Jaipur', phone='+91 90000 00001',
    shop_address='Studio 12, Artisan Lane, Jaipur, Rajasthan', seller_verified=true, is_public=true
  where id=seller_id;

  update public.profiles set
    role='customer', full_name='Mira Kapoor', seller_name='Mira Kapoor', city='Pune', phone='+91 90000 00002', blocked=false
  where id=customer_id;

  insert into public.categories(name,slug) values
    ('Jewellery','jewellery'),('Macramé','macrame'),('Home Décor','home-decor'),('Gifts','gifts'),
    ('Accessories','accessories'),('Art & Paintings','art-paintings'),('Paper Crafts','paper-crafts')
  on conflict(slug) do update set name=excluded.name;

  -- Remove only the original unowned sample rows created by older setup.sql files.
  delete from public.products as p where p.seller_id is null and p.name in (
    'Pearl Elegance Bracelet','Boho Macramé Wall Art','Artisan Ceramic Vase','Thoughtful Gift Box',
    'Bohemian Beaded Earrings','Handcrafted Tote Bag','Macramé Plant Hanger','Artisan Home Accent','Everyday Charm Bracelet'
  );

  insert into public.products(id,seller_id,name,description,category,price,stock,image_name,status,materials,tags,created_at) values
    ('a1000000-0000-4000-8000-000000000001',seller_id,'Pearl Elegance Bracelet','A delicate hand-strung bracelet with freshwater pearls and soft sage-green glass beads. Finished with a gold-tone clasp.','jewellery',299,24,'PearlEleganceBracelet.jpg','approved','Freshwater pearls, glass beads, gold-tone alloy',array['bracelet','pearls','gift','handmade'],now()),
    ('a1000000-0000-4000-8000-000000000002',seller_id,'Boho Macramé Wall Art','A textured statement wall hanging, knotted by hand from soft cotton cord in warm ivory and sea-glass tones.','macrame',899,12,'BohoMacrameWallArt.jpg','approved','Recycled cotton cord, natural wood dowel',array['macrame','wall art','boho','home décor'],now()),
    ('a1000000-0000-4000-8000-000000000003',seller_id,'Artisan Ceramic Vase','A one-of-a-kind ceramic vase with a hand-painted botanical motif. A beautiful centerpiece for fresh or dried flowers.','home-decor',549,15,'ArtisanCeramicVase.jpg','approved','Stoneware clay, food-safe glaze',array['ceramic','vase','home décor','botanical'],now()),
    ('a1000000-0000-4000-8000-000000000004',seller_id,'Thoughtful Gift Box','A ready-to-give collection of small handmade keepsakes, wrapped with care in recyclable paper and a cotton ribbon.','gifts',699,18,'ThoughtfulGiftBox.jpg','approved','Handmade keepsakes, recycled paper, cotton ribbon',array['gift box','celebration','ready to gift'],now()),
    ('a1000000-0000-4000-8000-000000000005',seller_id,'Bohemian Beaded Earrings','Lightweight statement earrings featuring a warm mix of handwoven beads and an easy-wear hook.','jewellery',349,20,'BohemianBeadedEarrings.jpg','approved','Glass beads, nickel-free hooks',array['earrings','beaded','lightweight'],now()),
    ('a1000000-0000-4000-8000-000000000006',seller_id,'Handcrafted Everyday Tote','A roomy, sturdy tote sewn in small batches from printed cotton. Finished with reinforced handles for daily use.','accessories',749,10,'HandcraftedToteBag.jpg','approved','Printed cotton, cotton lining',array['tote','cotton','everyday','reusable'],now()),
    ('a1000000-0000-4000-8000-000000000007',seller_id,'Macramé Plant Hanger','A simple hand-knotted hanger that brings a little greenery to a sunny corner. Fits most small and medium planters.','macrame',399,15,'MacramePlantHanger.jpg','approved','Cotton cord, wooden ring',array['macrame','plant hanger','home décor'],now()),
    ('a1000000-0000-4000-8000-000000000008',seller_id,'Sunlit Artisan Home Accent','A sculptural hand-finished accent piece made to add a warm, handmade touch to a shelf, desk, or bedside table.','home-decor',599,12,'ArtisanHomeAccent.jpg','approved','Stoneware clay, natural pigments',array['home décor','sculpture','shelf styling'],now()),
    ('a1000000-0000-4000-8000-000000000009',seller_id,'Everyday Charm Bracelet','A minimal charm bracelet assembled by hand with a small polished charm and an adjustable chain.','jewellery',199,25,'EverydayCharmBracelet.jpg','approved','Gold-tone alloy, glass charm',array['bracelet','minimal','everyday'],now()),
    ('a1000000-0000-4000-8000-000000000010',seller_id,'Botanical Paper Keepsake','A cheerful paper-crafted keepsake layered and assembled by hand. A thoughtful little accent for a desk or gift table.','paper-crafts',459,14,'PaperCraft.jpg','approved','Art paper, archival adhesive',array['paper craft','botanical','keepsake'],now()),
    ('a1000000-0000-4000-8000-000000000011',seller_id,'Jaipur Garden Painting','A small original floral painting inspired by the colors of a neighborhood garden. Each brushstroke is painted by hand.','art-paintings',1299,5,'painting.jpg','approved','Acrylic on canvas board',array['painting','floral','original art'],now())
  on conflict(id) do update set
    seller_id=excluded.seller_id,name=excluded.name,description=excluded.description,category=excluded.category,
    price=excluded.price,stock=excluded.stock,image_name=excluded.image_name,status=excluded.status,
    materials=excluded.materials,tags=excluded.tags,created_at=excluded.created_at;

  insert into public.orders(id,customer_id,status,payment_method,payment_status,subtotal,shipping,total,shipping_details,created_at) values
    ('b1000000-0000-4000-8000-000000000001',customer_id,'delivered','cod','not_processed',1198,0,1198,jsonb_build_object('full_name','Mira Kapoor','email',customer_email,'phone','+91 90000 00002','address','10 Demo Garden Road','city','Pune','state','Maharashtra','postal_code','411001','notes','Please leave at the front desk.'),now()-interval '12 days'),
    ('b1000000-0000-4000-8000-000000000002',customer_id,'shipped','cod','not_processed',549,49,598,jsonb_build_object('full_name','Mira Kapoor','email',customer_email,'phone','+91 90000 00002','address','10 Demo Garden Road','city','Pune','state','Maharashtra','postal_code','411001','notes',''),now()-interval '3 days'),
    ('b1000000-0000-4000-8000-000000000003',customer_id,'processing','cod','not_processed',1048,0,1048,jsonb_build_object('full_name','Mira Kapoor','email',customer_email,'phone','+91 90000 00002','address','10 Demo Garden Road','city','Pune','state','Maharashtra','postal_code','411001','notes','Gift wrap if possible.'),now()-interval '1 day'),
    ('b1000000-0000-4000-8000-000000000004',customer_id,'placed','cod','not_processed',399,49,448,jsonb_build_object('full_name','Mira Kapoor','email',customer_email,'phone','+91 90000 00002','address','10 Demo Garden Road','city','Pune','state','Maharashtra','postal_code','411001','notes',''),now()-interval '2 hours')
  on conflict(id) do update set status=excluded.status,payment_method=excluded.payment_method,payment_status=excluded.payment_status,
    subtotal=excluded.subtotal,shipping=excluded.shipping,total=excluded.total,shipping_details=excluded.shipping_details,created_at=excluded.created_at;

  insert into public.order_items(id,order_id,product_id,product_name,unit_price,quantity,customisation) values
    ('c1000000-0000-4000-8000-000000000001','b1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','Pearl Elegance Bracelet',299,1,''),
    ('c1000000-0000-4000-8000-000000000002','b1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000002','Boho Macramé Wall Art',899,1,'Please use the ivory cord.'),
    ('c1000000-0000-4000-8000-000000000003','b1000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000003','Artisan Ceramic Vase',549,1,''),
    ('c1000000-0000-4000-8000-000000000004','b1000000-0000-4000-8000-000000000003','a1000000-0000-4000-8000-000000000004','Thoughtful Gift Box',699,1,'Please include a handwritten note.'),
    ('c1000000-0000-4000-8000-000000000005','b1000000-0000-4000-8000-000000000003','a1000000-0000-4000-8000-000000000005','Bohemian Beaded Earrings',349,1,''),
    ('c1000000-0000-4000-8000-000000000006','b1000000-0000-4000-8000-000000000004','a1000000-0000-4000-8000-000000000007','Macramé Plant Hanger',399,1,'Natural cotton, please.')
  on conflict(id) do update set order_id=excluded.order_id,product_id=excluded.product_id,product_name=excluded.product_name,
    unit_price=excluded.unit_price,quantity=excluded.quantity,customisation=excluded.customisation;

  insert into public.reviews(id,product_id,customer_id,rating,title,reviewer_name,comment,created_at) values
    ('d1000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001',customer_id,5,'Even lovelier in person','Mira K.','The pearls are beautiful and the bracelet feels so thoughtfully made. It arrived carefully wrapped.',now()-interval '10 days'),
    ('d1000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002',customer_id,5,'A lovely focal point','Mira K.','The colors are soft and the knotting is excellent. It brightens up my reading nook.',now()-interval '8 days'),
    ('d1000000-0000-4000-8000-000000000003','a1000000-0000-4000-8000-000000000003',customer_id,4,'Beautiful handmade finish','Mira K.','A lovely little vase with a lot of character. It looks wonderful on our dining table.',now()-interval '5 days'),
    ('d1000000-0000-4000-8000-000000000004','a1000000-0000-4000-8000-000000000005',customer_id,5,'Light and comfortable','Mira K.','These are easy to wear all day and the colors go with everything.',now()-interval '4 days')
  on conflict(id) do update set rating=excluded.rating,title=excluded.title,reviewer_name=excluded.reviewer_name,comment=excluded.comment,created_at=excluded.created_at;

  insert into public.customer_queries(id,customer_id,product_id,order_id,product_name,message,response,status,created_at,responded_at) values
    ('e1000000-0000-4000-8000-000000000001',customer_id,'a1000000-0000-4000-8000-000000000003','b1000000-0000-4000-8000-000000000002','Artisan Ceramic Vase','Would this vase work for fresh flowers with water?','Yes, it has a food-safe glazed interior and is suitable for fresh flowers.','responded',now()-interval '6 days',now()-interval '5 days'),
    ('e1000000-0000-4000-8000-000000000002',customer_id,'a1000000-0000-4000-8000-000000000002','b1000000-0000-4000-8000-000000000001','Boho Macramé Wall Art','Could you make this in a slightly longer size?','I can make a custom 90 cm version. Please contact me before ordering so we can confirm the details.','responded',now()-interval '4 days',now()-interval '3 days'),
    ('e1000000-0000-4000-8000-000000000003',customer_id,'a1000000-0000-4000-8000-000000000007',null,'Macramé Plant Hanger','Which planter size fits best?','', 'open',now()-interval '1 day',null)
  on conflict(id) do update set product_id=excluded.product_id,order_id=excluded.order_id,product_name=excluded.product_name,
    message=excluded.message,response=excluded.response,status=excluded.status,created_at=excluded.created_at,responded_at=excluded.responded_at;

  insert into public.wishlists(user_id,product_id) values
    (customer_id,'a1000000-0000-4000-8000-000000000006'),(customer_id,'a1000000-0000-4000-8000-000000000011')
  on conflict(user_id,product_id) do nothing;
  insert into public.cart_items(user_id,product_id,quantity,customisation) values
    (customer_id,'a1000000-0000-4000-8000-000000000009',1,''),
    (customer_id,'a1000000-0000-4000-8000-000000000010',1,'Please use the blue paper accents.')
  on conflict(user_id,product_id,customisation) do update set quantity=excluded.quantity;

  insert into public.announcements(id,author_id,type,title,message,audience,created_at) values
    ('f1000000-0000-4000-8000-000000000001',seller_id,'Festival sale','A little handmade celebration','Enjoy 10% off selected pieces this week. Every order supports an independent maker.','everyone',now()-interval '2 days'),
    ('f1000000-0000-4000-8000-000000000002',seller_id,'Store announcement','Meet the maker','Our Jaipur studio is sharing a new collection of hand-knotted décor and small-batch gifts.','customers',now()-interval '1 day')
  on conflict(id) do update set type=excluded.type,title=excluded.title,message=excluded.message,audience=excluded.audience,created_at=excluded.created_at;
end $$;
