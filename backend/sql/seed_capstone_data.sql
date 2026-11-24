-- =====================================================================================
--  ResourceOne Capstone — Direct MySQL 8.0 Seed Data Script
--  Populates all 11 tables with realistic multi-tenant data for demo & evaluation.
--  Usage: mysql -u root -p resourceone < backend/sql/seed_capstone_data.sql
-- =====================================================================================

SET NAMES utf8mb4;
USE resourceone;
SET FOREIGN_KEY_CHECKS = 0;

-- Table: organizations
INSERT INTO `organizations` (`id`, `name`, `org_type`, `currency`, `created_at`) VALUES
(1, 'Community Relief Organization', 'ngo', 'INR', '2026-08-26 11:07:18.651785'),
(2, 'Sunrise Retail Store', 'retail', 'INR', '2026-08-26 11:07:18.651785');

-- Table: users
INSERT INTO `users` (`id`, `org_id`, `full_name`, `email`, `password_hash`, `role`, `is_active`, `created_at`) VALUES
(1, 1, 'Relief Administrator', 'admin@asha.org', '$argon2id$v=19$m=65536,t=3,p=4$FKf2WVfqy6h305UDefdU8w$ge2kFk6VF7ri2hSmwIe1L+c62EqGwiHqI5gcrHklJsc', 'admin', 1, '2026-08-31 11:07:18.651785'),
(2, 1, 'Relief Inventory Manager', 'manager@asha.org', '$argon2id$v=19$m=65536,t=3,p=4$FKf2WVfqy6h305UDefdU8w$ge2kFk6VF7ri2hSmwIe1L+c62EqGwiHqI5gcrHklJsc', 'manager', 1, '2026-08-31 11:07:18.651785'),
(3, 1, 'Relief Accountant', 'accounts@asha.org', '$argon2id$v=19$m=65536,t=3,p=4$FKf2WVfqy6h305UDefdU8w$ge2kFk6VF7ri2hSmwIe1L+c62EqGwiHqI5gcrHklJsc', 'accountant', 1, '2026-08-31 11:07:18.651785'),
(4, 1, 'Field Operations Volunteer', 'volunteer@asha.org', '$argon2id$v=19$m=65536,t=3,p=4$FKf2WVfqy6h305UDefdU8w$ge2kFk6VF7ri2hSmwIe1L+c62EqGwiHqI5gcrHklJsc', 'volunteer', 1, '2026-08-31 11:07:18.651785'),
(5, 2, 'Sunrise Store Owner', 'owner@sunrise.store', '$argon2id$v=19$m=65536,t=3,p=4$FKf2WVfqy6h305UDefdU8w$ge2kFk6VF7ri2hSmwIe1L+c62EqGwiHqI5gcrHklJsc', 'admin', 1, '2026-08-31 11:07:18.651785');

-- Table: inventory_items
INSERT INTO `inventory_items` (`id`, `org_id`, `name`, `sku`, `category`, `unit`, `quantity_on_hand`, `reorder_level`, `unit_cost`, `unit_price`, `expiry_date`, `is_archived`, `created_at`, `updated_at`) VALUES
(1, 1, 'Paracetamol 500mg (100 Tabs)', 'MED-PARA-500', 'Medical Relief', 'Box', 8, 20, 120, 0, '2027-05-23', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(2, 1, 'Sterile Gauze Bandage (Pack of 20)', 'MED-GAUZ-020', 'Medical Relief', 'Pack', 14, 25, 180, 0, '2027-11-19', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(3, 1, 'ORS Electrolyte Sachets (Box of 50)', 'MED-ORS-050', 'Medical Relief', 'Box', 75, 30, 250, 0, '2026-12-14', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(4, 1, 'Povidone Iodine Antiseptic 500ml', 'MED-IOD-500', 'Medical Relief', 'Bottle', 3, 15, 140, 0, '2027-06-12', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(5, 1, 'First Aid Medical Triage Kit', 'MED-KIT-001', 'Medical Relief', 'Kit', 0, 10, 950, 0, '2027-12-29', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(6, 1, 'Water Purification Chlorine Tablets (1000s)', 'SAN-WTR-1000', 'Sanitation & Water', 'Box', 42, 15, 450, 0, '2028-04-07', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(7, 1, 'Carbolic Disinfectant Soap (Pack of 12)', 'SAN-SOAP-012', 'Sanitation & Water', 'Pack', 6, 20, 180, 0, '2027-09-20', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(8, 1, 'Biodegradable Sanitary Pads (Pack of 30)', 'SAN-PADS-030', 'Sanitation & Water', 'Pack', 85, 30, 120, 0, '2028-07-16', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(9, 1, 'Surface Disinfectant Concentrate 5L', 'SAN-DIS-005', 'Sanitation & Water', 'Can', 18, 10, 650, 0, '2026-11-19', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(10, 1, 'Emergency Thermal Foil Blankets (Pack of 10)', 'LOG-BLNK-010', 'Disaster Logistics', 'Pack', 6, 15, 450, 0, NULL, 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(11, 1, 'Heavy-Duty Tarpaulin (12x15 ft)', 'LOG-TARP-012', 'Disaster Logistics', 'Sheet', 0, 10, 680, 0, NULL, 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(12, 1, 'Solar Rechargeable Relief Lantern 5W', 'LOG-SOLR-005', 'Disaster Logistics', 'Piece', 22, 10, 520, 0, NULL, 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(13, 1, 'High-Decibel Emergency Whistles (Box of 50)', 'LOG-WHS-050', 'Disaster Logistics', 'Box', 15, 8, 350, 0, NULL, 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(14, 1, 'Foldable Rescue Stretcher', 'LOG-STR-001', 'Disaster Logistics', 'Piece', 4, 5, 2200, 0, NULL, 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(15, 1, 'Fortified Wheat Flour 25kg Sack', 'FOD-WHT-025', 'Emergency Rations', 'Sack', 38, 20, 850, 0, '2027-02-22', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(16, 1, 'Fortified Long Grain Rice 25kg Sack', 'FOD-RCE-025', 'Emergency Rations', 'Sack', 45, 20, 1100, 0, '2027-03-24', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(17, 1, 'High-Energy Protein Nutri-Biscuits (Carton of 48)', 'FOD-ENB-048', 'Emergency Rations', 'Carton', 12, 15, 720, 0, '2026-12-09', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(18, 1, 'Iodized Salt 1kg Pack (Carton of 25)', 'FOD-SLT-025', 'Emergency Rations', 'Carton', 50, 15, 450, 0, '2027-12-29', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(19, 1, 'Refined Mustard Cooking Oil 5L Jar', 'FOD-OIL-005', 'Emergency Rations', 'Jar', 30, 15, 680, 0, '2027-07-22', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(20, 1, 'Split Red Lentils (Masoor Dal) 30kg Sack', 'FOD-DAL-030', 'Emergency Rations', 'Sack', 24, 12, 2400, 0, '2027-05-23', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(21, 2, 'Aashirvaad Shudh Chakki Atta 10kg', 'RET-ATTA-010', 'Grains & Pulses', 'Bag', 28, 10, 380, 440, '2027-03-24', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(22, 2, 'India Gate Basmati Rice Feast 5kg', 'RET-RCE-005', 'Grains & Pulses', 'Bag', 18, 8, 420, 520, '2027-09-20', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(23, 2, 'Tata Sampann Toor Dal 1kg', 'RET-TOOR-001', 'Grains & Pulses', 'Pkt', 5, 15, 145, 175, '2027-05-23', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(24, 2, 'Rajdhani Chana Dal 1kg', 'RET-CHNA-001', 'Grains & Pulses', 'Pkt', 35, 12, 85, 105, '2027-06-22', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(25, 2, 'Fortune Besan Gram Flour 1kg', 'RET-BSN-001', 'Grains & Pulses', 'Pkt', 0, 10, 82, 98, '2027-04-23', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(26, 2, 'Fortune Sunlite Refined Sunflower Oil 1L', 'RET-SFO-001', 'Cooking Oils & Ghee', 'Pouch', 40, 15, 118, 138, '2027-07-22', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(27, 2, 'Dhara Kachi Ghani Mustard Oil 1L Bottle', 'RET-MST-001', 'Cooking Oils & Ghee', 'Bottle', 22, 10, 142, 165, '2027-05-23', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(28, 2, 'Amul Pure Ghee 1L Tin', 'RET-GHE-001', 'Cooking Oils & Ghee', 'Tin', 4, 8, 560, 640, '2026-12-19', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(29, 2, 'Tata Salt Vacuum Evaporated 1kg', 'RET-SLT-001', 'Spices & Seasonings', 'Pkt', 65, 20, 22, 28, '2028-10-24', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(30, 2, 'MDH Deggi Mirch Powder 100g', 'RET-MRCH-100', 'Spices & Seasonings', 'Box', 28, 10, 72, 88, '2027-11-19', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(31, 2, 'Catch Turmeric Powder 200g', 'RET-HALD-200', 'Spices & Seasonings', 'Pkt', 30, 10, 48, 60, '2027-09-20', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(32, 2, 'Catch Coriander Powder 200g', 'RET-DHAN-200', 'Spices & Seasonings', 'Pkt', 7, 12, 52, 65, '2026-12-04', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(33, 2, 'Tata Tea Gold 500g Pack', 'RET-TEA-500', 'Snacks & Beverages', 'Pkt', 24, 10, 260, 310, '2027-11-24', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(34, 2, 'Nescafe Classic Coffee Jar 100g', 'RET-COF-100', 'Snacks & Beverages', 'Jar', 14, 8, 290, 345, '2027-12-29', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(35, 2, 'Parle-G Gold Biscuits (Pack of 12)', 'RET-PRLG-012', 'Snacks & Beverages', 'Pack', 48, 15, 110, 132, '2027-02-22', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(36, 2, 'Haldiram Bhujia Sev 400g Pouch', 'RET-BHUJ-400', 'Snacks & Beverages', 'Pouch', 0, 10, 95, 115, '2026-11-14', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(37, 2, 'Madhur Pure & Hygienic Sugar 5kg', 'RET-SUG-005', 'Snacks & Beverages', 'Bag', 16, 8, 215, 255, '2028-04-07', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(38, 2, 'Dettol Antiseptic Liquid 550ml', 'RET-DET-550', 'Personal & Home Care', 'Bottle', 18, 6, 175, 210, '2028-10-24', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(39, 2, 'Surf Excel Quick Wash Detergent 2kg', 'RET-SURF-002', 'Personal & Home Care', 'Pack', 20, 8, 295, 350, NULL, 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785'),
(40, 2, 'Colgate Strong Teeth Toothpaste 200g (Pack of 2)', 'RET-COLG-200', 'Personal & Home Care', 'Pack', 5, 12, 160, 195, '2028-02-17', 0, '2026-09-25 11:07:18.651785', '2026-11-23 11:07:18.651785');

-- Table: stock_movements
INSERT INTO `stock_movements` (`id`, `org_id`, `item_id`, `movement_type`, `quantity_delta`, `unit_value`, `total_value`, `reference_type`, `reference_id`, `note`, `actor_user_id`, `created_at`) VALUES
(1, 1, 1, 'RESTOCK', 18, 120, 2160, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(2, 1, 1, 'RELIEF', -10, 120, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(3, 1, 2, 'RESTOCK', 24, 180, 4320, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(4, 1, 2, 'RELIEF', -10, 180, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(5, 1, 3, 'RESTOCK', 85, 250, 21250, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(6, 1, 3, 'RELIEF', -10, 250, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(7, 1, 4, 'RESTOCK', 13, 140, 1820, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(8, 1, 4, 'RELIEF', -10, 140, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(9, 1, 5, 'RESTOCK', 10, 950, 9500, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(10, 1, 5, 'RELIEF', -10, 950, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(11, 1, 6, 'RESTOCK', 52, 450, 23400, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(12, 1, 6, 'RELIEF', -10, 450, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(13, 1, 7, 'RESTOCK', 16, 180, 2880, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(14, 1, 7, 'RELIEF', -10, 180, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(15, 1, 8, 'RESTOCK', 85, 120, 10200, 'purchase', NULL, 'Strategic humanitarian reserve batch intake', 2, '2026-09-10 11:07:18.651785'),
(16, 1, 9, 'RESTOCK', 28, 650, 18200, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(17, 1, 9, 'RELIEF', -10, 650, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(18, 1, 10, 'RESTOCK', 16, 450, 7200, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(19, 1, 10, 'RELIEF', -10, 450, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(20, 1, 11, 'RESTOCK', 10, 680, 6800, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(21, 1, 11, 'RELIEF', -10, 680, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(22, 1, 12, 'RESTOCK', 32, 520, 16640, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(23, 1, 12, 'RELIEF', -10, 520, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(24, 1, 13, 'RESTOCK', 25, 350, 8750, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(25, 1, 13, 'RELIEF', -10, 350, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(26, 1, 14, 'RESTOCK', 14, 2200, 30800, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(27, 1, 14, 'RELIEF', -10, 2200, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(28, 1, 15, 'RESTOCK', 48, 850, 40800, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(29, 1, 15, 'RELIEF', -10, 850, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(30, 1, 16, 'RESTOCK', 55, 1100, 60500, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(31, 1, 16, 'RELIEF', -10, 1100, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(32, 1, 17, 'RESTOCK', 22, 720, 15840, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(33, 1, 17, 'RELIEF', -10, 720, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(34, 1, 18, 'RESTOCK', 60, 450, 27000, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(35, 1, 18, 'RELIEF', -10, 450, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(36, 1, 19, 'RESTOCK', 40, 680, 27200, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(37, 1, 19, 'RELIEF', -10, 680, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(38, 1, 20, 'RESTOCK', 34, 2400, 81600, 'purchase', NULL, 'Initial batch intake from humanitarian supplier', 2, '2026-10-10 11:07:18.651785'),
(39, 1, 20, 'RELIEF', -10, 2400, 0, 'manual', NULL, 'Dispatched to district emergency relief camp', 4, '2026-11-09 11:07:18.651785'),
(40, 2, 21, 'RESTOCK', 43, 380, 16340, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(41, 2, 21, 'SALE', -15, 440, 6600, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(42, 2, 22, 'RESTOCK', 33, 420, 13860, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(43, 2, 22, 'SALE', -15, 520, 7800, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(44, 2, 23, 'RESTOCK', 20, 145, 2900, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(45, 2, 23, 'SALE', -15, 175, 2625, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(46, 2, 24, 'RESTOCK', 50, 85, 4250, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(47, 2, 24, 'SALE', -15, 105, 1575, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(48, 2, 25, 'RESTOCK', 15, 82, 1230, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(49, 2, 25, 'SALE', -15, 98, 1470, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(50, 2, 26, 'RESTOCK', 55, 118, 6490, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(51, 2, 26, 'SALE', -15, 138, 2070, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(52, 2, 27, 'RESTOCK', 37, 142, 5254, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(53, 2, 27, 'SALE', -15, 165, 2475, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(54, 2, 28, 'RESTOCK', 19, 560, 10640, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(55, 2, 28, 'SALE', -15, 640, 9600, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(56, 2, 29, 'RESTOCK', 65, 22, 1430, 'purchase', NULL, 'Bulk warehouse buffer stock intake', 5, '2026-09-10 11:07:18.651785'),
(57, 2, 30, 'RESTOCK', 43, 72, 3096, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(58, 2, 30, 'SALE', -15, 88, 1320, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(59, 2, 31, 'RESTOCK', 45, 48, 2160, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(60, 2, 31, 'SALE', -15, 60, 900, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(61, 2, 32, 'RESTOCK', 22, 52, 1144, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(62, 2, 32, 'SALE', -15, 65, 975, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(63, 2, 33, 'RESTOCK', 39, 260, 10140, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(64, 2, 33, 'SALE', -15, 310, 4650, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(65, 2, 34, 'RESTOCK', 29, 290, 8410, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(66, 2, 34, 'SALE', -15, 345, 5175, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(67, 2, 35, 'RESTOCK', 63, 110, 6930, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(68, 2, 35, 'SALE', -15, 132, 1980, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(69, 2, 36, 'RESTOCK', 15, 95, 1425, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(70, 2, 36, 'SALE', -15, 115, 1725, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(71, 2, 37, 'RESTOCK', 31, 215, 6665, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(72, 2, 37, 'SALE', -15, 255, 3825, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(73, 2, 38, 'RESTOCK', 33, 175, 5775, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(74, 2, 38, 'SALE', -15, 210, 3150, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(75, 2, 39, 'RESTOCK', 35, 295, 10325, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(76, 2, 39, 'SALE', -15, 350, 5250, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785'),
(77, 2, 40, 'RESTOCK', 20, 160, 3200, 'purchase', NULL, 'Stock procurement from wholesale mandi distributor', 5, '2026-10-05 11:07:18.651785'),
(78, 2, 40, 'SALE', -15, 195, 2925, 'manual', NULL, 'Walk-in retail customer sales ledger', 5, '2026-11-14 11:07:18.651785');

-- Table: purchases
INSERT INTO `purchases` (`id`, `org_id`, `item_id`, `invoice_no`, `supplier_name`, `quantity`, `unit_cost`, `total_amount`, `payment_status`, `purchase_date`, `created_by`, `created_at`) VALUES
(1, 1, 1, 'INV-ASHA-2026-001', 'National Pharma Relief Depot', 18, 120, 2160, 'paid', '2026-10-10', 2, '2026-10-10 11:07:18.651785'),
(2, 1, 15, 'INV-ASHA-2026-002', 'Kisan Food Agro Cooperative', 48, 850, 40800, 'paid', '2026-10-20', 2, '2026-10-20 11:07:18.651785'),
(3, 2, 21, 'INV-SUN-2026-001', 'ITC Wholesale Distribution Hub', 43, 380, 16340, 'paid', '2026-10-05', 5, '2026-10-05 11:07:18.651785'),
(4, 2, 26, 'INV-SUN-2026-002', 'Adani Wilmar Regional Depot', 55, 118, 6490, 'unpaid', '2026-11-19', 5, '2026-11-19 11:07:18.651785');

-- Table: donations
INSERT INTO `donations` (`id`, `org_id`, `donor_name`, `donation_type`, `amount`, `item_id`, `quantity`, `declared_value`, `purpose`, `receipt_no`, `donation_date`, `recorded_by`, `created_at`) VALUES
(1, 1, 'Azim Premji Philanthropic Initiatives', 'cash', 250000, NULL, NULL, 250000, 'Monsoon flood disaster emergency medical fund', 'DON-ASHA-2026-001', '2026-09-30', 3, '2026-09-30 11:07:18.651785'),
(2, 1, 'Rotary Club Gurugram North', 'goods', 0, 6, 20, 9000, 'Clean drinking water supply for flood shelter', 'DON-ASHA-2026-002', '2026-10-30', 4, '2026-10-30 11:07:18.651785'),
(3, 1, 'HDFC Parivartan CSR', 'cash', 150000, NULL, NULL, 150000, 'Nutritional rations relief for rural migrant workers', 'DON-ASHA-2026-003', '2026-11-12', 3, '2026-11-12 11:07:18.651785');

-- Table: cash_donations
INSERT INTO `cash_donations` (`donation_id`, `payment_mode`, `transaction_reference`, `bank_name`, `is_tax_exempt_80g`) VALUES
(1, 'NEFT', 'TXN-1-00001', 'HDFC Bank', 1),
(3, 'NEFT', 'TXN-1-00003', 'HDFC Bank', 1);

-- Table: in_kind_donations
INSERT INTO `in_kind_donations` (`donation_id`, `item_id`, `quantity_donated`, `unit_fair_value`, `storage_requirement`, `condition_grade`) VALUES
(2, 6, 20, 450, 'AMBIENT', 'NEW');

-- Table: expenses
INSERT INTO `expenses` (`id`, `org_id`, `category`, `amount`, `description`, `expense_date`, `receipt_no`, `recorded_by`, `created_at`) VALUES
(1, 1, 'transport', 14500, 'Relief supply diesel truck transport to Nuh district', '2026-10-15', 'EXP-ASHA-001', 3, '2026-10-15 11:07:18.651785'),
(2, 1, 'rent', 35000, 'Warehouse storage hub monthly lease rental', '2026-10-25', 'EXP-ASHA-002', 3, '2026-10-25 11:07:18.651785'),
(3, 1, 'supplies', 4200, 'Corrugated packing cartons and sealing tapes', '2026-11-06', 'EXP-ASHA-003', 3, '2026-11-06 11:07:18.651785'),
(4, 2, 'rent', 22000, 'Commercial shop space rent for October', '2026-10-30', 'EXP-SUN-001', 5, '2026-10-30 11:07:18.651785'),
(5, 2, 'utilities', 6850, 'DHBVN commercial electricity power bill', '2026-11-10', 'EXP-SUN-002', 5, '2026-11-10 11:07:18.651785');

-- Table: warehouses
INSERT INTO `warehouses` (`id`, `org_id`, `warehouse_code`, `name`, `city`, `capacity_sqft`, `is_active`, `created_at`) VALUES
(1, 1, 'WH-NORTH', 'Noida Relief Warehouse', 'Noida', 24000, 1, '2026-11-24 11:07:18.838209'),
(2, 1, 'WH-WEST', 'Gurugram Transit Depot', 'Gurugram', 12000, 1, '2026-11-24 11:07:18.838209'),
(3, 2, 'WH-MAIN', 'Sunrise Main Store', 'Gurgaon', 9000, 1, '2026-11-24 11:07:18.838209'),
(4, 2, 'WH-BACK', 'Sunrise Backroom Reserve', 'Gurgaon', 3500, 1, '2026-11-24 11:07:18.838209');

-- Table: warehouse_stock
INSERT INTO `warehouse_stock` (`id`, `warehouse_id`, `item_id`, `quantity_stored`, `bin_location`, `last_counted_at`) VALUES
(1, 1, 1, 4, 'AISLE-1-SHELF-A', '2026-11-24 11:07:18.838209'),
(2, 2, 1, 4, 'AISLE-1-SHELF-A', '2026-11-24 11:07:18.838209'),
(3, 1, 2, 7, 'AISLE-2-SHELF-B', '2026-11-24 11:07:18.838209'),
(4, 2, 2, 7, 'AISLE-2-SHELF-B', '2026-11-24 11:07:18.838209'),
(5, 1, 3, 37.5, 'AISLE-3-SHELF-C', '2026-11-24 11:07:18.838209'),
(6, 2, 3, 37.5, 'AISLE-3-SHELF-C', '2026-11-24 11:07:18.838209'),
(7, 1, 4, 1.5, 'AISLE-4-SHELF-D', '2026-11-24 11:07:18.838209'),
(8, 2, 4, 1.5, 'AISLE-4-SHELF-D', '2026-11-24 11:07:18.838209'),
(9, 1, 5, 0, 'AISLE-1-SHELF-E', '2026-11-24 11:07:18.838209'),
(10, 2, 5, 0, 'AISLE-1-SHELF-E', '2026-11-24 11:07:18.838209'),
(11, 1, 6, 21, 'AISLE-2-SHELF-F', '2026-11-24 11:07:18.838209'),
(12, 2, 6, 21, 'AISLE-2-SHELF-F', '2026-11-24 11:07:18.838209'),
(13, 1, 7, 3, 'AISLE-3-SHELF-A', '2026-11-24 11:07:18.838209'),
(14, 2, 7, 3, 'AISLE-3-SHELF-A', '2026-11-24 11:07:18.838209'),
(15, 1, 8, 42.5, 'AISLE-4-SHELF-B', '2026-11-24 11:07:18.838209'),
(16, 2, 8, 42.5, 'AISLE-4-SHELF-B', '2026-11-24 11:07:18.838209'),
(17, 1, 9, 9, 'AISLE-1-SHELF-C', '2026-11-24 11:07:18.838209'),
(18, 2, 9, 9, 'AISLE-1-SHELF-C', '2026-11-24 11:07:18.838209'),
(19, 1, 10, 3, 'AISLE-2-SHELF-D', '2026-11-24 11:07:18.838209'),
(20, 2, 10, 3, 'AISLE-2-SHELF-D', '2026-11-24 11:07:18.838209'),
(21, 1, 11, 0, 'AISLE-3-SHELF-E', '2026-11-24 11:07:18.838209'),
(22, 2, 11, 0, 'AISLE-3-SHELF-E', '2026-11-24 11:07:18.838209'),
(23, 1, 12, 11, 'AISLE-4-SHELF-F', '2026-11-24 11:07:18.838209'),
(24, 2, 12, 11, 'AISLE-4-SHELF-F', '2026-11-24 11:07:18.838209'),
(25, 1, 13, 7.5, 'AISLE-1-SHELF-A', '2026-11-24 11:07:18.838209'),
(26, 2, 13, 7.5, 'AISLE-1-SHELF-A', '2026-11-24 11:07:18.838209'),
(27, 1, 14, 2, 'AISLE-2-SHELF-B', '2026-11-24 11:07:18.838209'),
(28, 2, 14, 2, 'AISLE-2-SHELF-B', '2026-11-24 11:07:18.838209'),
(29, 1, 15, 19, 'AISLE-3-SHELF-C', '2026-11-24 11:07:18.838209'),
(30, 2, 15, 19, 'AISLE-3-SHELF-C', '2026-11-24 11:07:18.838209'),
(31, 1, 16, 22.5, 'AISLE-4-SHELF-D', '2026-11-24 11:07:18.838209'),
(32, 2, 16, 22.5, 'AISLE-4-SHELF-D', '2026-11-24 11:07:18.838209'),
(33, 1, 17, 6, 'AISLE-1-SHELF-E', '2026-11-24 11:07:18.838209'),
(34, 2, 17, 6, 'AISLE-1-SHELF-E', '2026-11-24 11:07:18.838209'),
(35, 1, 18, 25, 'AISLE-2-SHELF-F', '2026-11-24 11:07:18.838209'),
(36, 2, 18, 25, 'AISLE-2-SHELF-F', '2026-11-24 11:07:18.838209'),
(37, 1, 19, 15, 'AISLE-3-SHELF-A', '2026-11-24 11:07:18.838209'),
(38, 2, 19, 15, 'AISLE-3-SHELF-A', '2026-11-24 11:07:18.838209'),
(39, 1, 20, 12, 'AISLE-4-SHELF-B', '2026-11-24 11:07:18.838209'),
(40, 2, 20, 12, 'AISLE-4-SHELF-B', '2026-11-24 11:07:18.838209'),
(41, 3, 21, 14, 'AISLE-1-SHELF-A', '2026-11-24 11:07:18.838209'),
(42, 4, 21, 14, 'AISLE-1-SHELF-A', '2026-11-24 11:07:18.838209'),
(43, 3, 22, 9, 'AISLE-2-SHELF-B', '2026-11-24 11:07:18.838209'),
(44, 4, 22, 9, 'AISLE-2-SHELF-B', '2026-11-24 11:07:18.838209'),
(45, 3, 23, 2.5, 'AISLE-3-SHELF-C', '2026-11-24 11:07:18.838209'),
(46, 4, 23, 2.5, 'AISLE-3-SHELF-C', '2026-11-24 11:07:18.838209'),
(47, 3, 24, 17.5, 'AISLE-4-SHELF-D', '2026-11-24 11:07:18.838209'),
(48, 4, 24, 17.5, 'AISLE-4-SHELF-D', '2026-11-24 11:07:18.838209'),
(49, 3, 25, 0, 'AISLE-1-SHELF-E', '2026-11-24 11:07:18.838209'),
(50, 4, 25, 0, 'AISLE-1-SHELF-E', '2026-11-24 11:07:18.838209'),
(51, 3, 26, 20, 'AISLE-2-SHELF-F', '2026-11-24 11:07:18.838209'),
(52, 4, 26, 20, 'AISLE-2-SHELF-F', '2026-11-24 11:07:18.838209'),
(53, 3, 27, 11, 'AISLE-3-SHELF-A', '2026-11-24 11:07:18.838209'),
(54, 4, 27, 11, 'AISLE-3-SHELF-A', '2026-11-24 11:07:18.838209'),
(55, 3, 28, 2, 'AISLE-4-SHELF-B', '2026-11-24 11:07:18.838209'),
(56, 4, 28, 2, 'AISLE-4-SHELF-B', '2026-11-24 11:07:18.838209'),
(57, 3, 29, 32.5, 'AISLE-1-SHELF-C', '2026-11-24 11:07:18.838209'),
(58, 4, 29, 32.5, 'AISLE-1-SHELF-C', '2026-11-24 11:07:18.838209'),
(59, 3, 30, 14, 'AISLE-2-SHELF-D', '2026-11-24 11:07:18.838209'),
(60, 4, 30, 14, 'AISLE-2-SHELF-D', '2026-11-24 11:07:18.838209'),
(61, 3, 31, 15, 'AISLE-3-SHELF-E', '2026-11-24 11:07:18.838209'),
(62, 4, 31, 15, 'AISLE-3-SHELF-E', '2026-11-24 11:07:18.838209'),
(63, 3, 32, 3.5, 'AISLE-4-SHELF-F', '2026-11-24 11:07:18.838209'),
(64, 4, 32, 3.5, 'AISLE-4-SHELF-F', '2026-11-24 11:07:18.838209'),
(65, 3, 33, 12, 'AISLE-1-SHELF-A', '2026-11-24 11:07:18.838209'),
(66, 4, 33, 12, 'AISLE-1-SHELF-A', '2026-11-24 11:07:18.838209'),
(67, 3, 34, 7, 'AISLE-2-SHELF-B', '2026-11-24 11:07:18.838209'),
(68, 4, 34, 7, 'AISLE-2-SHELF-B', '2026-11-24 11:07:18.838209'),
(69, 3, 35, 24, 'AISLE-3-SHELF-C', '2026-11-24 11:07:18.838209'),
(70, 4, 35, 24, 'AISLE-3-SHELF-C', '2026-11-24 11:07:18.838209'),
(71, 3, 36, 0, 'AISLE-4-SHELF-D', '2026-11-24 11:07:18.838209'),
(72, 4, 36, 0, 'AISLE-4-SHELF-D', '2026-11-24 11:07:18.838209'),
(73, 3, 37, 8, 'AISLE-1-SHELF-E', '2026-11-24 11:07:18.838209'),
(74, 4, 37, 8, 'AISLE-1-SHELF-E', '2026-11-24 11:07:18.838209'),
(75, 3, 38, 9, 'AISLE-2-SHELF-F', '2026-11-24 11:07:18.838209'),
(76, 4, 38, 9, 'AISLE-2-SHELF-F', '2026-11-24 11:07:18.838209'),
(77, 3, 39, 10, 'AISLE-3-SHELF-A', '2026-11-24 11:07:18.838209'),
(78, 4, 39, 10, 'AISLE-3-SHELF-A', '2026-11-24 11:07:18.838209'),
(79, 3, 40, 2.5, 'AISLE-4-SHELF-B', '2026-11-24 11:07:18.838209'),
(80, 4, 40, 2.5, 'AISLE-4-SHELF-B', '2026-11-24 11:07:18.838209');

SET FOREIGN_KEY_CHECKS = 1;
-- Direct MySQL Seed complete!
