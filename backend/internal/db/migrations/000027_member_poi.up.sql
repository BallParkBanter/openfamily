-- Bray piece 5: the nearest named feature ("Near Dacula High School").
--
-- Written by the family geocoder alongside street/city/county from the SAME
-- Nominatim reverse call (no extra requests). poi_kind is a small fixed
-- vocabulary (home, school, airport, shop, restaurant, park, work, medical,
-- gym, church, other) the app maps to an icon; poi_name is the feature's
-- name. Both NULL on a plain street.
ALTER TABLE member_geocodes
    ADD COLUMN poi_name text,
    ADD COLUMN poi_kind text;
