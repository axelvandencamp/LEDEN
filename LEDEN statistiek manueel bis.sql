--------------------------------------
-- NIEUWE LEDEN
-- NIET HERNIEUWDE LEDEN
-- OPGEZEGDE LEDEN: onmiddellijk of eind v jaar
-- OPGEZEGDE LEDEN: ondertussen inactief
--------------------------------------
--SET VARIABLES
DROP TABLE IF EXISTS myvar;
SELECT 
	'2021-01-01'::date AS startdatum 
	,'2021-12-31'::date AS einddatum
	,'2017-01-01'::date AS cutoffdate --te gebruiken bij jaarovergang om nieuwe leden nieuwe jaar af te trekken van tellen voorbije jaar
	,'1999-01-01'::date AS basedatum
	,'123333'::numeric AS ledenaantal_vorigjaar --eind 2016 
	--,'97362'::numeric AS ledenaantal_vorigjaar --eind 2015 
	--,'95163'::numeric AS ledenaantal_vorigjaar --einde 2014
	--,'14-221-295'::text AS uittreksel
INTO TEMP TABLE myvar;
SELECT * FROM myvar;
------------------------------------------------
	
--------------------------------------------------
--OPGEZEGDE LEDEN: onmiddellijk of eind v jaar
-----------------
SELECT p.id, p.name, p.membership_state, p.membership_end, ml.date_cancel, ml.state
FROM myvar v, 
	res_partner p
	JOIN membership_membership_line ml ON p.id = ml.partner
WHERE ml.date_cancel BETWEEN v.startdatum AND v.einddatum
	AND p.membership_end >= now()::date --opzeg op einde vh jaar
	--AND p.membership_end >= '2020-12-31' --opzeg op einde vh jaar **** specifief voor jaareinde ****
	--AND p.membership_end < now()::date --onmiddellijke opzeg
	--AND p.membership_end < '2020-12-31' --onmiddellijke opzeg **** specifief voor jaareinde ****
	AND p.active = 't'
--------------------------------------------------
--OPGEZEGDE LEDEN: ondertussen inactief
-----------------
SELECT p.id, p.name, p.membership_state, p.membership_end, ml.date_cancel, ml.state
FROM myvar v, 
	res_partner p
	JOIN membership_membership_line ml ON p.id = ml.partner
WHERE ml.date_cancel BETWEEN v.startdatum AND v.einddatum
	AND p.active = 'f'
	