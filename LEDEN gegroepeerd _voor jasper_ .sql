-----------------------------------------
-- leden gegroepeerd
-- --
-- leden stat. man.
-----------------------------------------

--=================================================================
--
-- REGEL voor ivm uitsluiting opgezegden herzien (of procedure van opzegging)
--
--=================================================================
--SET VARIABLES
DROP TABLE IF EXISTS _AV_myvar;
CREATE TEMP TABLE _AV_myvar 
	(startdatum DATE, einddatum DATE,
	 prm_groep text,
	 ledenvorigjaar NUMERIC
	 );

INSERT INTO _AV_myvar VALUES('2023-01-01',	--startdatum
				'2024-12-31',	--einddatum
				'wervende_organisatie', --groep   ('afdeling','woonplaats','provincie','herkomst_lidmaatschap','wervende_organisatie')
				131703
				);
SELECT * FROM _AV_myvar;
--====================================================================
--====================================================================
SELECT
	CASE WHEN v.prm_groep = 'afdeling' THEN sq1.afdeling_id
		WHEN v.prm_groep = 'woonplaats' THEN sq1.postcode END id,
	CASE WHEN v.prm_groep = 'afdeling' THEN sq1.afdeling  
		WHEN v.prm_groep = 'woonplaats' THEN sq1.woonplaats 
		WHEN v.prm_groep = 'provincie' THEN sq1.provincie 
		WHEN v.prm_groep = 'herkomst_lidmaatschap' THEN sq1.herkomst_lidmaatschap 
		WHEN v.prm_groep = 'wervende_organisatie' THEN sq1.wervende_organisatie END naam,
	COUNT(partner_id) aantal, 
	CASE WHEN v.prm_groep = ('wervende_organisatie') THEN SUM(via_website) END aantal_2,
	CASE WHEN v.prm_groep = ('wervende_organisatie') THEN SUM(via_andere) END aantal_3
--SELECT afdeling_id, afdeling, COUNT(partner_id) aantal_leden
--SELECT postcode, woonplaats, COUNT(partner_id) aantal_leden
--SELECT provincie, COUNT(partner_id) aantal_leden
--SELECT herkomst_lidmaatschap, COUNT(partner_id) aantal_leden
--SELECT wervende_organisatie, COUNT(partner_id) aantal_leden, SUM(via_website) via_website, SUM(via_andere) via_andere
FROM _av_myvar v, (
	SELECT	DISTINCT--COUNT(p.id) _aantal, now()::date vandaag
		p.id partner_id, 
		CASE WHEN COALESCE(p.free_member,'f') = 'f' THEN 0 ELSE 1 END gratis_lid,
		p.membership_nbr lidnummer, 
		CASE
			WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip
			ELSE p.zip
		END postcode,
		CASE 
			WHEN c.id = 21 THEN cc.name ELSE p.city 
		END woonplaats,
		CASE
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 1000 AND 1299 THEN 'Brussel' 
			WHEN p.country_id = 21 AND (substring(p.zip from '[0-9]+')::numeric BETWEEN 1500 AND 1999 OR substring(p.zip from '[0-9]+')::numeric BETWEEN 3000 AND 3499) THEN 'Vlaams Brabant'
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 2000 AND 2999  THEN 'Antwerpen' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 3500 AND 3999  THEN 'Limburg' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 8000 AND 8999  THEN 'West-Vlaanderen' 
			WHEN p.country_id = 21 AND substring(p.zip from '[0-9]+')::numeric BETWEEN 9000 AND 9999  THEN 'Oost-Vlaanderen' 
			WHEN p.country_id = 21 THEN 'Wallonië'
			WHEN p.country_id = 166 THEN 'Nederland'
			WHEN NOT(p.country_id IN (21,166)) THEN 'Buitenland niet NL'
			ELSE 'andere'
		END AS provincie,
		_crm_land(c.id) land,
		a.id::text afdeling_id,
		COALESCE(a.name,'onbekend') Afdeling,
		COALESCE(mo.name,'') herkomst_lidmaatschap,
		p.membership_state huidige_lidmaatschap_status,
		p5.name wervende_organisatie,
		CASE
			WHEN p.address_state_id = 2 THEN 1 ELSE 0
		END adres_verkeerd,
		CASE
			WHEN COALESCE(sm.sm_id,0) > 0 THEN 1 ELSE 0
		END DOMI,
		CASE
			WHEN p.membership_start >= v.startdatum THEN 1 ELSE 0
		END nieuw_lid,
		CASE WHEN login = 'apiuser' THEN 1 ELSE 0 END via_website,
		CASE WHEN login <> 'apiuser' THEN 1 ELSE 0 END via_andere,
		CASE WHEN (NOT(COALESCE(p.email_work,p.email) IS NULL) OR COALESCE(p.email_work,p.email) <> '') THEN 1 ELSE 0 END email,
		CASE WHEN (p.phone <> '' OR NOT(p.phone IS NULL) OR p.phone_work <> '' 
		 		OR NOT(p.phone_work IS NULL) OR p.mobile <> '' OR NOT(p.mobile IS NULL)) THEN 1 ELSE 0 END telefoon
	FROM 	_av_myvar v, res_partner p
		--aangemaakt door 
		JOIN res_users u ON u.id = p.create_uid
		--Voor de ontdubbeling veroorzaakt door meedere lidmaatschapslijnen
		--LEFT OUTER JOIN (SELECT * FROM _av_myvar v, membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id WHERE  ml.date_to BETWEEN v.startdatum and v.einddatum AND pp.membership_product) ml ON ml.partner = p.id
		--idem: versie voor jaarwisseling (januari voor vorige jaar)
		--LEFT OUTER JOIN (SELECT * FROM _av_myvar v, membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id WHERE  ml.state = 'paid' AND ml.date_to BETWEEN v.startdatum and v.einddatum AND pp.membership_product) ml ON ml.partner = p.id
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON COALESCE(p.department_choice_id,p.department_id) = a.id
		--bank/mandaat info
		--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
		LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
		--wervende organisatie
		LEFT OUTER JOIN res_partner p5 ON p.recruiting_organisation_id = p5.id
	--=============================================================================
	WHERE 	p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		AND p.membership_state IN ('paid','invoiced','free') -- **** uitschakelen voor jaarovergang ****
	) sq1
WHERE
	CASE WHEN v.prm_groep IN ('herkomst_lidmaatschap','wervende_organisatie') THEN nieuw_lid = 1 END
GROUP BY 
	CASE WHEN v.prm_groep = 'afdeling' THEN afdeling_id 
		WHEN v.prm_groep = 'woonplaats' THEN postcode END,
	CASE WHEN v.prm_groep = 'afdeling' THEN afdeling  
		WHEN v.prm_groep = 'woonplaats' THEN woonplaats 
		WHEN v.prm_groep = 'provincie' THEN provincie 
		WHEN v.prm_groep = 'herkomst_lidmaatschap' THEN herkomst_lidmaatschap 
		WHEN v.prm_groep = 'wervende_organisatie' THEN wervende_organisatie END, 
	v.prm_groep
--GROUP BY postcode, woonplaats
--GROUP BY provincie
--WHERE nieuw_lid = 1
--GROUP BY herkomst_lidmaatschap
--GROUP BY wervende_organisatie


--------------------------------
-- leden stat.man.
--------------------------------
SELECT 'Leden' teller, COUNT(DISTINCT p.id) aantal
FROM 	_AV_myvar v, res_partner p
WHERE 	p.active = 't'	AND COALESCE(p.deceased,'f') = 'f' AND COALESCE(p.free_member,'f') = 'f' AND p.membership_state IN ('paid','invoiced')
UNION ALL
SELECT 	'Gratis leden', COUNT(DISTINCT p.id)
FROM 	_AV_myvar v, res_partner p 
WHERE 	(p.free_member = 't') AND p.active = 't' AND COALESCE(p.deceased,'f') = 'f'
UNION ALL
SELECT 'Niewe leden', COUNT(DISTINCT p.id)
FROM _AV_myvar v, res_partner p
WHERE p.membership_state IN ('paid','invoiced','free') AND p.membership_start >= v.startdatum
UNION ALL
SELECT 'uitval_aantal', COUNT(p.id) aantal
FROM _AV_myvar v, res_partner p
WHERE (p.membership_end = (v.startdatum + INTERVAL 'day -1')::date AND NOT(p.membership_state IN ('canceled','invoiced')))
UNION ALL
SELECT 'uitval_perc', (((COUNT(p.id))::decimal(7,2)/131703)*100)::decimal(5,2)   
FROM _AV_myvar v, res_partner p
WHERE (p.membership_end = (v.startdatum + INTERVAL 'day -1')::date AND NOT(p.membership_state IN ('canceled','invoiced')))
UNION ALL
SELECT 	'Leden met mandaat', COUNT(DISTINCT p.id)
FROM 	_AV_myvar v, res_partner p
	JOIN membership_membership_line ml ON ml.partner = p.id
	--bank/mandaat info
	LEFT OUTER JOIN res_partner_bank pb ON pb.partner_id = p.id
	LEFT OUTER JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id
WHERE 	p.active = 't'	AND COALESCE(p.deceased,'f') = 'f' AND p.membership_state IN ('paid','invoiced','free')
	--enkel lidmaatschapsproduct lijnen met een einddatum in 2015
	AND sm.state = 'valid'
	AND COALESCE(ml.date_cancel,'2099-12-31') > now()::date
	--opzeggingen met een opzegdatum na vandaag (voor vandaag worden niet meegenomen)
	AND (ml.state = 'paid' AND COALESCE(sm.id,0) <> 0
	-- betaald lidmaatschap met domi
		OR ((ml.state = 'invoiced' AND COALESCE(sm.id,0) <> 0)))
UNION ALL
SELECT 'adres_verkeerd_lid', COUNT(p.id) aantal
FROM _AV_myvar v, res_partner p
WHERE (p.membership_state IN ('paid','invoiced','free')) AND p.address_state_id = 2 AND p.active AND COALESCE(p.deceased,'f') = 'f'
UNION ALL
SELECT 'adres_verkeerd_niethernieuwd', COUNT(p.id) aantal
FROM _AV_myvar v, res_partner p
WHERE (p.membership_state IN ('wait_member')) AND p.address_state_id = 2 AND p.active AND COALESCE(p.deceased,'f') = 'f'
UNION ALL
SELECT 'via website', COUNT(p.id)
FROM	_av_myvar v, res_partner p
	JOIN res_users u ON p.create_uid = u.id
WHERE p.active AND p.membership_state IN ('paid','invoiced') AND p.create_date BETWEEN v.startdatum AND v.einddatum AND u.login = 'apiuser'
UNION ALL
SELECT 'via website pending', COUNT(p.id)
FROM	_av_myvar v, res_partner p
	JOIN res_users u ON p.create_uid = u.id
WHERE p.active AND p.membership_state IN ('none') AND p.create_date BETWEEN v.startdatum AND v.einddatum AND u.login = 'apiuser'
UNION ALL
SELECT 'via website dubbel', COUNT(p2.id) + COUNT(p3.id)
FROM	_av_myvar v, res_partner p
	JOIN res_users u ON p.create_uid = u.id
	--partners die ook terugkomen als "active_partner_id" bij geïnactiveerden
	LEFT OUTER JOIN res_partner p2 ON p.id = p2.active_partner_id
	--actieve partner uit de geïnactiveerde partner
	LEFT OUTER JOIN res_partner p3 ON p.active_partner_id = p3.id
	LEFT OUTER JOIN res_users u2 ON p2.create_uid = u2.id
	LEFT OUTER JOIN partner_inactive pi ON p2.inactive_id = pi.id
WHERE p.create_date BETWEEN v.startdatum AND v.einddatum AND (u.login IN ('apiuser','apiuser_educatie') OR u2.login IN ('apiuser','apiuser_educatie'))
UNION ALL
SELECT 	'opzeg_onmiddellijk', COUNT(DISTINCT sq1.id)
FROM (
	SELECT p.id, p.name, p.membership_state, p.membership_end, ml.date_cancel, ml.state
	FROM _AV_myvar v, 
		res_partner p
		JOIN membership_membership_line ml ON p.id = ml.partner
	WHERE ml.date_cancel BETWEEN v.startdatum AND v.einddatum
		AND p.membership_end < now()::date --onmiddellijke opzeg
		--AND p.membership_end < '2020-12-31' --onmiddellijke opzeg **** specifief voor jaareinde ****
		AND p.active = 't'
	) SQ1
UNION ALL
SELECT 	'opzeg_eindejaar:', COUNT(DISTINCT sq1.id)
FROM (
	SELECT p.id, p.name, p.membership_state, p.membership_end, ml.date_cancel, ml.state
	FROM _AV_myvar v, 
		res_partner p
		JOIN membership_membership_line ml ON p.id = ml.partner
	WHERE ml.date_cancel BETWEEN v.startdatum AND v.einddatum
		AND p.membership_end >= now()::date --opzeg op einde vh jaar
		--AND p.membership_end >= '2020-12-31' --opzeg op einde vh jaar **** specifief voor jaareinde ****
		AND p.active = 't'	
	) SQ1
UNION ALL
SELECT 	'opzeg_inactief', COUNT(DISTINCT sq1.id)
	FROM (
		SELECT p.id, p.name, p.membership_state, p.membership_end, ml.date_cancel, ml.state
		FROM _AV_myvar v, 
			res_partner p
			JOIN membership_membership_line ml ON p.id = ml.partner
		WHERE ml.date_cancel BETWEEN v.startdatum AND v.einddatum
			--AND p.membership_start < '2023-01-01' -- jaarovergang
			AND p.active = 'f'	
		) SQ1
UNION ALL
SELECT 	'Adreswijziging via Ledenservice', COUNT(x.id)
FROM	_AV_myvar v, 
		(SELECT ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) AS r, p.id p_id, pah.*, u.login
		FROM res_partner p 
			JOIN res_partner_address_history pah ON p.id = pah.partner_id
			JOIN res_users u ON pah.write_uid = u.id
		) x	
WHERE x.r > 1 -- orig lijn is geen adreswijziging
	AND x.date_move BETWEEN v.startdatum and v.einddatum AND x.login IN ('axel.vandencamp','vera.baetens','kristien.vercauteren','griet.vandendriessche')
UNION ALL
SELECT 	'Adreswijziging via website', COUNT(x.id)
FROM	_AV_myvar v, 
		(SELECT ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) AS r, p.id p_id, pah.*, u.login
		FROM res_partner p 
			JOIN res_partner_address_history pah ON p.id = pah.partner_id
			JOIN res_users u ON pah.write_uid = u.id
		) x	
WHERE x.r > 1 -- orig lijn is geen adreswijziging
	AND x.date_move BETWEEN v.startdatum and v.einddatum AND x.login = 'apiuser'
UNION ALL
SELECT 	'Adreswijziging via administrator', COUNT(x.id)
FROM	_AV_myvar v, 
		(SELECT ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) AS r, p.id p_id, pah.*, u.login
		FROM res_partner p 
			JOIN res_partner_address_history pah ON p.id = pah.partner_id
			JOIN res_users u ON pah.write_uid = u.id
		) x	
WHERE x.r > 1 -- orig lijn is geen adreswijziging
	AND x.date_move BETWEEN v.startdatum and v.einddatum AND x.login = 'admin'	
UNION ALL
SELECT 	'Adreswijziging via andere', COUNT(x.id)
FROM	_AV_myvar v, 
		(SELECT ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) AS r, p.id p_id, pah.*, u.login
		FROM res_partner p 
			JOIN res_partner_address_history pah ON p.id = pah.partner_id
			JOIN res_users u ON pah.write_uid = u.id
		) x	
WHERE x.r > 1 -- orig lijn is geen adreswijziging
	AND x.date_move BETWEEN v.startdatum and v.einddatum 
	AND NOT(x.login IN ('axel.vandencamp','vera.baetens','kristien.vercauteren','griet.vandendriessche','apiuser','admin'))
UNION ALL
SELECT 	'fout adres', COUNT(DISTINCT p.id)
FROM 	_AV_myvar v, res_partner p
WHERE 	(membership_state_b IN ('paid','invoiced','wait_member','free') OR p.free_member = 't') AND p.address_state_id = 2
UNION ALL
SELECT 	'email adres', COUNT(DISTINCT p.id)
FROM 	_AV_myvar v, res_partner p
WHERE p.active = 't' AND COALESCE(p.deceased,'f') = 'f'
	AND p.membership_state IN ('paid','invoiced','free')
	AND (NOT(COALESCE(p.email_work,p.email) IS NULL) OR COALESCE(p.email_work,p.email) <> '') 
UNION ALL
SELECT 	'telnr', COUNT(DISTINCT p.id)
FROM 	_AV_myvar v, res_partner p
WHERE 	(membership_state_b IN ('paid','invoiced','free') OR p.free_member = 't')
	AND (p.phone <> '' OR NOT(p.phone IS NULL) OR p.phone_work <> '' OR NOT(p.phone_work IS NULL) OR p.mobile <> '' OR NOT(p.mobile IS NULL))
					   
					   
				   
