--------------------------------------------------------------
-- aanmaak myvar
----------------
--SET VARIABLES
-- - v.startdatum = 1e dag vanaf wanneer de nieuwe leden moeten opgehaald worden
-- - v.lidnummer = het laatste lidnummer aangemaakt de dag voor v.startdatum
DROP TABLE IF EXISTS _AV_myvar;

CREATE TEMP TABLE _AV_myvar (startdatum DATE, einddatum DATE, eindhuidigjaar DATE);

INSERT INTO _AV_myvar VALUES('2021-01-01',	--startdatum
				'2021-12-31',	--einddatum
				'2019-12-31');	--eindhuidigjaar

SELECT * FROM _AV_myvar;
--------------------------------------------------------------
-- aanmaak _AV_temp_PARTNERIDs
------------------------------
DROP TABLE IF EXISTS _AV_temp_PARTNERIDs;

CREATE TEMP TABLE _AV_temp_PARTNERIDs (
	partner_id NUMERIC, lid NUMERIC, nieuw NUMERIC, gratis_lid NUMERIC, niet_hernieuwd NUMERIC, donateur NUMERIC);
--------------------------------------------------------------
-- vullen _AV_temp_PARTNERIDs
-----------------------------
INSERT INTO _AV_temp_PARTNERIDs
	(SELECT id, 0, 0, 0, 0, 0 FROM res_partner);
-- SELECT * FROM _AV_temp_PARTNERIDs
--------------------------------------------------------------
-- leden toevoegen
------------------
UPDATE _AV_temp_PARTNERIDs
SET lid = 1
WHERE _AV_temp_PARTNERIDs.partner_id IN
	(SELECT DISTINCT p.id	
	FROM 	_av_myvar v, res_partner p
		LEFT OUTER JOIN (SELECT ml.* FROM _av_myvar v, membership_membership_line ml JOIN product_product pp ON ml.membership_id = pp.id WHERE  ml.date_to BETWEEN v.startdatum and v.einddatum AND pp.membership_product) ml ON ml.partner = p.id
		JOIN product_product pp ON ml.membership_id = pp.id
		LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	WHERE 	p.active = 't'	
		AND COALESCE(p.deceased,'f') = 'f' 
		AND COALESCE(p.free_member,'f') = 'f'
	 	AND p.membership_state IN ('paid','invoiced')
		/*AND (ml.date_from BETWEEN v.startdatum and v.einddatum OR v.startdatum BETWEEN ml.date_from AND ml.date_to) AND pp.membership_product 
		AND (COALESCE(ml.date_cancel,'2099-12-31')) > now()::date
		AND (ml.state = 'paid'
			OR ((ml.state = 'invoiced' AND COALESCE(sm.sm_id,0) <> 0)
				OR (ml.state = 'invoiced' AND COALESCE(i.partner_id,0) <> 0 AND COALESCE(a3.organisation_type_id,0) = 1 )))*/
	UNION ALL
	SELECT DISTINCT p.id	
	FROM 	_av_myvar v, res_partner p
	WHERE 	p.active = 't'	
		AND COALESCE(p.deceased,'f') = 'f' 
		AND COALESCE(p.free_member,'f') = 't')	;
--------------------------------------------------------------
-- gratis leden toevoegen
-------------------------
UPDATE _AV_temp_PARTNERIDs
SET gratis_lid = 1
WHERE _AV_temp_PARTNERIDs.partner_id IN
	(SELECT DISTINCT p.id	
	FROM 	_av_myvar v, res_partner p
	WHERE 	p.active = 't'	
		AND COALESCE(p.deceased,'f') = 'f' 
		AND COALESCE(p.free_member,'f') = 't');	
--------------------------------------------------------------
-- nieuwe leden toevoegen
-------------------------
UPDATE _AV_temp_PARTNERIDs
SET nieuw = 1
WHERE _AV_temp_PARTNERIDs.partner_id IN
	(SELECT DISTINCT p.id
	FROM _av_myvar v, res_partner p
	WHERE p.membership_state IN ('paid','invoiced','free')
		AND p.membership_start >= v.startdatum);
--------------------------------------------------------------
-- niet hernieuwde leden toevoegen
----------------------------------
UPDATE _AV_temp_PARTNERIDs
SET niet_hernieuwd = 1
WHERE _AV_temp_PARTNERIDs.partner_id IN
	(SELECT DISTINCT p.id
	FROM _av_myvar v, res_partner p
	WHERE p.membership_end = (v.startdatum + INTERVAL 'day -1')::date
		AND p.membership_state <> 'canceled');
--------------------------------------------------------------
-- aanmaak _AV_temp_PARTNERIDs
------------------------------
/* -- _dim_PARTNER: partner info kan beter uit _crm_partnerinfo() komen; puur voor cijfers is die info ook niet nodig;
DROP TABLE IF EXISTS _AV_temp_dim_PARTNER;

CREATE TEMP TABLE _AV_temp_dim_PARTNER (
	partner_id NUMERIC, provincie TEXT, afdeling TEXT, herkomst_lidmaatschap TEXT, wervende_organisatie TEXT, datum DATE);
--------------------------------------------------------------	
-- _AV_temp_dim_PARTNER vullen 
------------------------------
INSERT INTO _AV_temp_dim_PARTNER
	(SELECT	p.id,
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
		COALESCE(COALESCE(a2.name,a.name),'onbekend') Afdeling,
		mo.name herkomst_lidmaatschap,
		p5.name wervende_organisatie,
		NULL datum
	FROM 	myvar v, res_partner p
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		LEFT OUTER JOIN res_partner p5 ON p.recruiting_organisation_id = p5.id
	WHERE p.id IN (SELECT partner_id FROM _AV_temp_PARTNERIDs WHERE lid = 1 OR niet_hernieuwd = 1)
	);
*/
--------------------------------------------------------------
-- aanmaak _AV_temp_fact_PARTNER
--------------------------------
DROP TABLE IF EXISTS _AV_temp_fact_PARTNER;

CREATE TEMP TABLE _AV_temp_fact_PARTNER (
	partner_id NUMERIC, via_afdeling NUMERIC, DOMI NUMERIC, via_website NUMERIC, via_website_pending NUMERIC, via_andere NUMERIC, dubbel_via_website NUMERIC, focus NUMERIC, oriolus NUMERIC, zoogdier NUMERIC, 
	adreswijziging_ledenadministratie NUMERIC, adreswijziging_website NUMERIC, adreswijziging_administrator NUMERIC, adreswijziging_andere NUMERIC, fout_adres NUMERIC, met_email_adres NUMERIC, met_telefoonnr NUMERIC);
--------------------------------------------------------------
-- _AV_temp_fact_PARTNER vullen
--------------------------------
INSERT INTO _AV_temp_fact_PARTNER	
	(SELECT	p.id,
		CASE
			WHEN COALESCE(p.recruiting_organisation_id,0) > 0 THEN 1 ELSE 0
		END via_afdeling,
		CASE
			WHEN COALESCE(sm.sm_id,0) > 0 THEN 1 ELSE 0
		END DOMI,
		CASE WHEN u.login = 'apiuser' THEN 1 ELSE 0 END via_website,
		CASE WHEN u.login = 'apiuser' AND p.membership_state = 'none' THEN 1 ELSE 0 END via_website_pending,
		CASE WHEN u.login <> 'apiuser' THEN 1 ELSE 0 END via_andere,
		0 dubbel_via_website, -- toevoegen via UPDATE !!
		--CASE WHEN (u.login IN ('apiuser') OR u2.login IN ('apiuser') OR u3.login IN ('apiuser'))
		--	AND (COALESCE(p2.id,0) <> 0 OR COALESCE(p3.id,0) <> 0) THEN 1 ELSE 0 END dubbel_via_website,
		0 focus, -- toevoegen via UPDATE !!
		0 oriolus, -- toevoegen via UPDATE !!
		0 zoogdier, -- toevoegen via UPDATE !!
		--CASE WHEN mm.product_id = 3 THEN 1 ELSE 0 END focus,
		--CASE WHEN mm.product_id = 4 THEN 1 ELSE 0 END oriolus,
		--CASE WHEN mm.product_id = 204 THEN 1 ELSE 0 END zoogdier,
		0 adreswijziging_ledenadministratie, -- toevoegen via UPDATE !!
		0 adreswijziging_website, -- toevoegen via UPDATE !!
		0 adreswijziging_administrator, -- toevoegen via UPDATE !!
		0 adreswijziging_andere, -- toevoegen via UPDATE !!
		--CASE WHEN ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) > 1 AND u4.login IN ('axel','vera','janvdb','linsay','kristienv') THEN 1 ELSE 0 END adreswijziging_ledenadministratie,
		--CASE WHEN ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) > 1 AND u4.login = 'apiuser' THEN 1 ELSE 0 END adreswijziging_website,
		--CASE WHEN ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) > 1 AND u4.login = 'admin' THEN 1 ELSE 0 END adreswijziging_administrator,
		--CASE WHEN ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) > 1 AND (NOT(u4.login = 'admin') AND NOT(u4.login = 'apiuser') AND NOT(u4.login IN ('axel','vera','janvdb','linsay','kristienv'))) THEN 1 ELSE 0 END adreswijziging_andere,
		CASE
			WHEN p.address_state_id = 2 THEN 1 ELSE 0
		END fout_adres,
		CASE WHEN (p.email <> '' OR NOT(p.email IS NULL) OR p.email_work <> '' OR NOT(p.email_work IS NULL)) THEN 1 ELSE 0 END met_email_adres,
		CASE WHEN (p.phone <> '' OR NOT(p.phone IS NULL) OR p.phone_work <> '' OR NOT(p.phone_work IS NULL) OR p.mobile <> '' OR NOT(p.mobile IS NULL)) THEN 1 ELSE 0 END met_telefoonnr	
	FROM 	_av_myvar v, res_partner p
		JOIN res_users u ON u.id = p.create_uid
		--bank/mandaat info
		LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
		--adreswijzigingen
		--!!!!!!!!!!!!!!!!!!!!!!!!
		--!!!!! geeft exra's !!!!!
		--!!!!!!!!!!!!!!!!!!!!!!!!
		--JOIN res_partner_address_history pah ON p.id = pah.partner_id
		--JOIN res_users u4 ON pah.write_uid = u4.id
		--magazines
		--!!!!!!!!!!!!!!!!!!!!!!!!
		--!!!!! geeft exra's !!!!!
		--!!!!!!!!!!!!!!!!!!!!!!!!
		/*LEFT OUTER JOIN (SELECT pp.name_template, mm.* 
			FROM myvar v, membership_membership_magazine mm	JOIN product_product pp ON pp.id = mm.product_id
			WHERE mm.date_to >= v.eindhuidigjaar AND COALESCE(date_cancel,'2099-01-01') > now()::date) mm ON mm.partner_id = p.id*/
		--dubbels
		--!!!!!!!!!!!!!!!!!!!!!!!!
		--!!!!! geeft exra's !!!!!
		--!!!!!!!!!!!!!!!!!!!!!!!!
		--LEFT OUTER JOIN res_partner p2 ON p2.id = p.active_partner_id 
		/*LEFT OUTER JOIN res_users u2 ON p2.create_uid = u2.id
		LEFT OUTER JOIN partner_inactive pi2 ON pi2.id = p2.inactive_id 
		LEFT OUTER JOIN res_partner p3 ON p3.active_partner_id  = p.id
		LEFT OUTER JOIN res_users u3 ON p3.create_uid = u3.id
		LEFT OUTER JOIN partner_inactive pi3 ON pi2.id = p3.inactive_id */
	WHERE p.id IN (SELECT partner_id FROM _AV_temp_PARTNERIDs)	
	);
--------------------------------------------------------------
-- _AV_temp_fact_PARTNER adreswijzigingen toevoegen
-- nog na te kijken: vergelijken met huidige rapportage: vanwaar komt verschil??
-- SELECT * FROM res_users u WHERE login LIKE '%jim%' AND active
---------------------------------------------------
UPDATE _AV_temp_fact_PARTNER t1
SET adreswijziging_ledenadministratie = sq2.adreswijziging_ledenadministratie,
	adreswijziging_website = sq2.adreswijziging_website,
	adreswijziging_administrator = sq2.adreswijziging_administrator,
	adreswijziging_andere = sq2.adreswijziging_andere
FROM	(SELECT sq1.p_id,
		CASE WHEN sq1.login IN ('axel','vera','janvdb','linsay','kristienv','jimmy') THEN 1 ELSE 0 END adreswijziging_ledenadministratie,
		CASE WHEN sq1.login = 'apiuser' THEN 1 ELSE 0 END adreswijziging_website,
		CASE WHEN sq1.login = 'admin' THEN 1 ELSE 0 END adreswijziging_administrator,
		CASE WHEN (NOT(sq1.login = 'admin') AND NOT(sq1.login = 'apiuser') AND NOT(sq1.login IN ('axel','vera','janvdb','linsay','kristienv','jimmy'))) THEN 1 ELSE 0 END adreswijziging_andere
	--SELECT DISTINCT sq1.p_id	
	FROM 	_AV_myvar v, 
		(SELECT ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) AS r,
		p.id p_id, pah.*, 
		u.login
		FROM res_partner p 
			JOIN res_partner_address_history pah ON p.id = pah.partner_id
			JOIN res_users u ON pah.write_uid = u.id
		--WHERE p.id = 133065 
		) sq1
	--WHERE p.id IN (SELECT partner_id FROM _AV_temp_PARTNERIDs) sq1
	WHERE sq1.r > 1 AND sq1.date_move BETWEEN v.startdatum and v.eindhuidigjaar ) sq2
WHERE sq2.p_id = t1.partner_id;
--------------------------------------------------------------
-- _AV_temp_fact_PARTNER magazines toevoegen
-- ook licht hoger: nakijken waar het verschil zit
--------------------------------------------
UPDATE _AV_temp_fact_PARTNER t1
SET focus = sq1.focus,
	oriolus = sq1.oriolus,
	zoogdier = sq1.zoogdier
FROM (	SELECT t1.partner_id p_id,
		CASE WHEN mm.product_id = 3 AND mm.date_to >= v.eindhuidigjaar AND COALESCE(mm.date_cancel,'2099-01-01') > now()::date THEN 1 ELSE 0 END focus,
		CASE WHEN mm.product_id = 4 AND mm.date_to >= v.eindhuidigjaar AND COALESCE(mm.date_cancel,'2099-01-01') > now()::date THEN 1 ELSE 0 END oriolus,
		CASE WHEN mm.product_id = 204 AND mm.date_to >= v.eindhuidigjaar AND COALESCE(mm.date_cancel,'2099-01-01') > now()::date THEN 1 ELSE 0 END zoogdier
	FROM _AV_myvar v, _AV_temp_fact_PARTNER t1
		--JOIN res_partner p ON p.id = t1.partner_id
		JOIN membership_membership_magazine mm ON t1.partner_id = mm.partner_id
		JOIN product_product pp ON pp.id = mm.product_id
	) sq1
WHERE sq1.p_id = t1.partner_id;
--==========================================================================================================
--==========================================================================================================
--==========================================================================================================
--SELECT  * FROM _AV_temp_fact_PARTNER 
--/*
 
SELECT *

SELECT p.partner_id, sum(lid) lid, sum(nieuw) nieuw, sum(gratis_lid) gratis_lid, sum(niet_hernieuwd) niet_hernieuwd, sum(donateur) donateur, sum(via_afdeling) via_afdeling, sum(domi) domi, sum(via_website) via_website, sum(via_website_pending) via_website_pending, sum(via_andere) via_andere, sum(dubbel_via_website) dubbel_via_website, sum(focus) focus, sum(oriolus) oriolus, sum(zoogdier) zoogdier, sum(adreswijziging_website) adreswijziging_website, sum(adreswijziging_administrator) adreswijziging_administrator, sum(adreswijziging_andere) adreswijziging_andere, sum(fout_adres) fout_adres, sum(met_email_adres) met_email_adres, sum(met_telefoonnr) met_telefoonnr
	, pd.provincie, pd.afdeling, pd.herkomst_lidmaatschap, pd.wervende_organisatie, pd.datum 
FROM _AV_temp_PARTNERIDs p
	JOIN _AV_temp_dim_PARTNER pd ON pd.partner_id = p.partner_id
	JOIN _AV_temp_fact_PARTNER pf ON pf.partner_id = p.partner_id
GROUP BY p.partner_id, provincie, afdeling, herkomst_lidmaatschap, wervende_organisatie, datum

SELECT DISTINCT COUNT(p.partner_id) partner_id
SELECT *
FROM _AV_temp_PARTNERIDs p
	JOIN _AV_temp_dim_PARTNER pd ON pd.partner_id = p.partner_id
	JOIN _AV_temp_fact_PARTNER pf ON pf.partner_id = p.partner_id
WHERE p.niet_hernieuwd > 0 AND p.lid > 0
--WHERE nieuw = 1 AND via_afdeling = 1
--WHERE p.lid = 1 AND pf.domi = 1
--WHERE nieuw = 1 AND via_website = 1
--WHERE nieuw = 1 AND via_website_pending = 1
--WHERE nieuw = 1 AND via_andere = 1
--WHERE nieuw = 1 AND dubbel_via_website = 1
--WHERE lid = 1 AND focus = 1
--WHERE lid = 1 AND oriolus = 1
--WHERE lid = 1 AND zoogdier = 1
--WHERE adreswijziging_ledenadministratie = 1
--WHERE adreswijziging_website = 1
--WHERE adreswijziging_administrator = 1
--WHERE adreswijziging_andere = 1
--WHERE lid = 1 AND fout_adres = 1
--WHERE lid = 1 AND met_email_adres = 1
--WHERE lid = 1 AND met_telefoonnr = 1

--WHERE niet_hernieuwd = 1 AND gratis_lid = 0

--*/
-- SELECT * FROM product_product WHERE membership_product

--------------------------
--test dubbels via website
--------------------------
/*
SELECT p.create_date::date date, p.id p_id, p.active_partner_id, p.membership_state, p.active p_active, pi.name,
	p2.id p2_id, p2.active_partner_id, p2.inactive_id p2_inactive_id, p2.membership_state, p2.active p2_active, pi2.name,
	p3.id p3_id, p3.active_partner_id p3_active_partner_id, p3.membership_state p3_state, p3.active p3_active
FROM	myvar v,
	res_partner p
	JOIN res_users u ON p.create_uid = u.id 
	LEFT OUTER JOIN partner_inactive pi ON pi.id = p.inactive_id 
	--partners die ook terugkomen als "active_partner_id" bij geïnactiveerden
	LEFT OUTER JOIN res_partner p2 ON p2.id = p.active_partner_id 
	LEFT OUTER JOIN res_users u2 ON p2.create_uid = u2.id
	LEFT OUTER JOIN partner_inactive pi2 ON pi2.id = p2.inactive_id 
	--actieve partner uit de geïnactiveerde partner
	LEFT OUTER JOIN res_partner p3 ON p3.active_partner_id  = p.id
	LEFT OUTER JOIN res_users u3 ON p3.create_uid = u3.id
	LEFT OUTER JOIN partner_inactive pi3 ON pi2.id = p3.inactive_id 
	--JOIN partner_inactive pi ON p2.inactive_id = pi.id
WHERE 	--alle partners aangemaakt tijdens gevraagde period (zowel actief als inactief)
	p.create_date BETWEEN v.startdatum AND v.einddatum
	AND (u.login IN ('apiuser') OR u2.login IN ('apiuser') OR u3.login IN ('apiuser'))
	AND (COALESCE(p2.id,0) <> 0 OR COALESCE(p3.id,0) <> 0)
*/	

	
