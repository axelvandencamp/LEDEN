-----------------------------------------

--SET VARIABLES
DROP TABLE IF EXISTS myvar;
SELECT 
	'2022-01-01'::date AS startdatum, 
	'2022-12-31'::date AS einddatum  --vanaf 01/07 lid tot einde volgende jaar
INTO TEMP TABLE myvar;
SELECT * FROM myvar;
--====================================================================
--Partners (actief of inactief) 
-- - waarvan het geïnactiveerde lid dit jaar werd aangemaakt
-- - de geïnactiveerde werd aangemaakt via de website ('apiuser' of 'apiuser_educatie') 
--====================================================================
SELECT p.id id1, p.membership_nbr lidnr1, p.name naam1, p.create_date::date created1, p.membership_state status1, p.active active1, u.login login1,
	p2.id id2, p2.name naam2, p2.create_date::date created2, p2.active active2, u2.login login2,
	pi.name redenincactief2,
	p3.id id3, p3.name naam3, p3.membership_start start3, p3.membership_state status3, p3.active active3,
	CASE
		WHEN u.login = 'apiuser' AND p.active THEN 1 ELSE 0
	END actief_lid_via_website
FROM	myvar v,
	res_partner p
	JOIN res_users u ON p.create_uid = u.id
	--partners die ook terugkomen als "active_partner_id" bij geïnactiveerden
	LEFT OUTER JOIN res_partner p2 ON p.id = p2.active_partner_id
	--actieve partner uit de geïnactiveerde partner
	LEFT OUTER JOIN res_partner p3 ON p.active_partner_id = p3.id
	LEFT OUTER JOIN res_users u2 ON p2.create_uid = u2.id
	LEFT OUTER JOIN partner_inactive pi ON p2.inactive_id = pi.id
WHERE 	--alle partners aangemaakt tijdens gevraagde period (zowel actief als inactief)
	p.create_date BETWEEN v.startdatum AND v.einddatum
	AND (u.login IN ('apiuser','apiuser_educatie') OR u2.login IN ('apiuser','apiuser_educatie'))
	--AND p.membership_start < '2023-01-01' --JAAROVERGANG
	--AND u.login IN ('apiuser','apiuser_educatie')
	--AND COALESCE(pi2.id,0) >  0
	--AND p.active
	--AND p.crab_used = 'false'
	--AND p.membership_state IN ('paid','invoiced')
--SELECT * FROM partner_inactive LIMIT 100	
/*
SELECT *
FROM myvar v, res_partner p
	JOIN res_users u ON p.create_uid = u.id
WHERE u.login = 'apiuser_educatie' AND p.active
	AND p.create_date BETWEEN v.startdatum AND v.einddatum
*/