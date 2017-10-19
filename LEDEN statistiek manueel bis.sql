--------------------------------------
-- NIEUWE LEDEN
-- NIET HERNIEUWDE LEDEN
-- OPGEZEGDE LEDEN: onmiddellijk of eind v jaar
-- OPGEZEGDE LEDEN: ondertussen inactief
--------------------------------------
--SET VARIABLES
DROP TABLE IF EXISTS myvar;
SELECT 
	'2017-01-01'::date AS startdatum 
	,'2017-12-31'::date AS einddatum
	,'2017-01-01'::date AS cutoffdate --te gebruiken bij jaarovergang om nieuwe leden nieuwe jaar af te trekken van tellen voorbije jaar
	,'1999-01-01'::date AS basedatum
	,'102324'::numeric AS ledenaantal_vorigjaar --eind 2016 
	--,'97362'::numeric AS ledenaantal_vorigjaar --eind 2015 
	--,'95163'::numeric AS ledenaantal_vorigjaar --einde 2014
	--,'14-221-295'::text AS uittreksel
INTO TEMP TABLE myvar;
SELECT * FROM myvar;
------------------------------------------------
--NIEUWE LEDEN
--------------
SELECT DISTINCT p.id, p.membership_state, p.membership_start, p.membership_stop, p.membership_end, p.membership_pay_date
FROM myvar v, res_partner p
WHERE p.membership_state IN ('paid','invoiced','free')
	AND p.membership_start >= v.startdatum
	-- extra controle op startdatum van het lidmaatschap (enkel nodig bij jaarovergang om leden in het nieuwe jaar gecreëerd af te trekken van de "huidige toestand" van het vorige jaar)
	--AND p.membership_start < v.cutoffdate
-------------------------------------------------
--NIET HERNIEUWDE LEDEN
-----------------------
SELECT p.id, p.membership_state, p.membership_start, p.membership_stop, p.membership_end, p.membership_cancel, p.membership_pay_date, (v.startdatum + INTERVAL'day -1')::date
FROM myvar v, res_partner p
WHERE p.membership_end = (v.startdatum + INTERVAL 'day -1')::date
	AND p.membership_state <> 'canceled'
--------------------------------------------------
--OPGEZEGDE LEDEN: onmiddellijk of eind v jaar
-----------------
SELECT p.id, p.name, p.membership_state, p.membership_end, ml.date_cancel, ml.state
FROM myvar v, 
	res_partner p
	JOIN membership_membership_line ml ON p.id = ml.partner
WHERE ml.date_cancel BETWEEN v.startdatum AND v.einddatum
	AND p.membership_end >= now()::date --opzeg op einde vh jaar
	--AND p.membership_end < now()::date --onmiddellijke opzeg
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
	