--=================================================================
--SET VARIABLES
-- - v.startdatum = 1e dag vanaf wanneer de nieuwe leden moeten opgehaald worden
-- - v.lidnummer = het laatste lidnummer aangemaakt de dag voor v.startdatum
DROP TABLE IF EXISTS _AV_myvar;

CREATE TEMP TABLE _AV_myvar (startdatum DATE, lidnummer TEXT, afdeling NUMERIC[]);

INSERT INTO _AV_myvar VALUES('2018-04-01',	--startdatum
				null,		--lidnummer
				'{248599}');	--lijst afdelingen

UPDATE _AV_myvar
SET lidnummer = membership_nbr FROM (SELECT MAX(membership_nbr) membership_nbr FROM _AV_myvar v, res_partner p WHERE create_date::date = v.startdatum - (interval '1 day')) sq1;
SELECT * FROM _AV_myvar;
--====================================================================
--lijst ID's nieuwe leden
--=======================
DROP TABLE IF EXISTS _AV_tempIDs_nieuweleden;

CREATE TEMP TABLE _AV_tempIDs_nieuweleden (partner_id NUMERIC, N NUMERIC, G NUMERIC, O1 NUMERIC, "5J" NUMERIC, "1-5J" NUMERIC, V NUMERIC, O2 NUMERIC);

--nieuwe leden obv lidnummer toevoegen - N -
INSERT INTO _AV_tempIDs_nieuweleden
	(SELECT p.id, 1 N, 0 G, 0 O1, 0 "5J", 0 "1-5J", 0 V, 0 O2
	FROM _AV_myvar v, res_partner p
		JOIN membership_membership_line ml ON ml.partner = p.id
		JOIN product_product pp ON pp.id = ml.membership_id
	WHERE 	pp.membership_product 
		AND (membership_nbr >=  v.lidnummer AND (NOT(membership_start IS NULL)) OR (membership_nbr >=  v.lidnummer AND free_member))
		--AND NOT (p.id IN (SELECT id FROM _crm_leden5j(v.lidnummer,v.startdatum)))
		--AND NOT (p.id IN (SELECT id FROM _crm_ledennieuwlatergevalideerd(v.lidnummer,v.startdatum)))
	);

--"gratis" nieuwe leden toevoegen - G -
INSERT INTO _AV_tempIDs_nieuweleden
	(SELECT p.id, 0 N, 1 G, 0 O1, 0 "5J", 0 "1-5J", 0 V, 0 O2
	FROM _AV_myvar v, res_partner p
	WHERE p.free_member AND p.active AND p.create_date::date >  v.startdatum 	
	);

--nieuwe leden met oud lidnummer die pas recent betaalden toevoegen - O1 - 
INSERT INTO _AV_tempIDs_nieuweleden
	(SELECT p.id, 0 N, 0 G, 1 O1, 0 "5J", 0 "1-5J", 0 V, 0 O2
	FROM _AV_myvar v, res_partner p
		JOIN membership_membership_line ml ON ml.partner = p.id
		JOIN product_product pp ON pp.id = ml.membership_id
		--bank/mandaat info
		--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
		LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
		--facturen info
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		--parnter info
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	WHERE pp.membership_product
		AND p.membership_nbr < v.lidnummer   
		AND p.membership_pay_date >=  v.startdatum
		AND date_part('year',age(p.membership_stop, p.membership_start)) <= 0
		AND NOT(p.membership_start IS NULL)
		AND NOT (p.id IN (SELECT id FROM _crm_ledenviaafdeling( v.lidnummer, v.startdatum  )))
		AND NOT (p.id IN (SELECT id FROM _crm_ledenmetdomi( v.lidnummer, v.startdatum  )))
		AND NOT (p.id IN (SELECT id FROM _crm_ledenviateinnenoverschrijving( v.lidnummer, v.startdatum )))
		--AND NOT (p.id IN (SELECT id FROM _crm_ledennieuwlatergevalideerd( v.lidnummer, v.startdatum)))
		--AND NOT (p.id IN (SELECT id FROM _crm_ledenoudepartnernieuwlid( v.lidnummer, v.startdatum)))
		AND COALESCE(sm.pb_partner_id,0) = 0
		AND NOT(COALESCE(i.partner_id,0) <> 0 AND COALESCE(a3.organisation_type_id,0) = 1 )	
	);

--leden die langer dan 5j geen lid meer waren - 5j -
INSERT INTO _AV_tempIDs_nieuweleden
	(SELECT id, 0 N, 0 G, 0 O1, 1 "5J", 0 "1-5J", 0 V, 0 O2 FROM _AV_myvar v, _crm_leden5j(v.lidnummer,v.startdatum)	
	);

--leden die 1 tot 5j geen lid meer waren - 1-5j -
INSERT INTO _AV_tempIDs_nieuweleden
	(SELECT id, 0 N, 0 G, 0 O1, 0 "5J", 1 "1-5J", 0 V, 0 O2 FROM _AV_myvar v, _crm_leden1tot5j(v.lidnummer,v.startdatum)	
	);

--nieuwe leden die later gevalideerd werden (kleiner v.lidnummer, maar wel gevalideerd na de v.startdatum) - V -
INSERT INTO _AV_tempIDs_nieuweleden
	(SELECT id, 0 N, 0 G, 0 O1, 0 "5J", 0 "1-5J", 1 V, 0 O2 FROM _AV_myvar v, _crm_ledennieuwlatergevalideerd( v.lidnummer,v.startdatum)
		--WHERE NOT (id IN (SELECT id FROM _AV_myvar v, _crm_leden1tot5j( v.lidnummer,v.startdatum)))
		--	AND NOT (id IN (SELECT id FROM _AV_myvar v, _crm_leden5j(v.lidnummer,v.startdatum)))
	);	

--oude partner_id, nieuw lid - O2 -
INSERT INTO _AV_tempIDs_nieuweleden
	(SELECT id, 0 N, 0 G, 0 O1, 0 "5J", 0 "1-5J", 0 V, 1 O2 FROM _AV_myvar v, _crm_ledenoudepartnernieuwlid( v.lidnummer,v.startdatum)
		--WHERE NOT (id IN (SELECT id FROM _crm_ledennieuwlatergevalideerd( v.lidnummer,v.startdatum)))	
	);
--====================================================================
SELECT * FROM _AV_tempIDs_nieuweleden;

SELECT	DISTINCT--COUNT(p.id) _aantal, now()::date vandaag
	p.id database_id, 
	p2.N, p2.G, p2.O1, p2."5J", p2."1-5J", p2.V, p2.O2,
	p.membership_nbr lidnummer, 
	p.first_name as voornaam,
	p.last_name as achternaam,
	CASE
		WHEN c.id = 21 AND p.crab_used = 'true' THEN ccs.name
		ELSE p.street
	END straat,
	p.street2 building,
	CASE
		WHEN c.id = 21 AND p.crab_used = 'true' THEN p.street_nbr ELSE ''
	END huisnummer, 
	p.street_bus bus,
	CASE
		WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip
		ELSE p.zip
	END postcode,
	CASE 
		WHEN c.id = 21 THEN cc.name ELSE p.city 
	END woonplaats,
	p.postbus_nbr postbus,
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
	c.name land,
	p.email,
	COALESCE(COALESCE(a2.name,a.name),'onbekend') Afdeling,
	mo.name herkomst_lidmaatschap,
	p.membership_state huidige_lidmaatschap_status,
	COALESCE(p.create_date::date,p.membership_start) aanmaak_datum,
	p.membership_start Lidmaatschap_startdatum, 
	p.membership_stop Lidmaatschap_einddatum,  
	p.membership_pay_date betaaldatum,
	p.membership_renewal_date hernieuwingsdatum,
	p.membership_end recentste_einddatum_lidmaatschap,
	p.membership_cancel membership_cancel,
	_crm_opzegdatum_membership(p.id) opzegdatum_LML,
	p.active/*,
	p2.name wervend_lid,
	p2.membership_nbr wl_lidnummer,
	p5.name wervende_organisatie,
	CASE
		WHEN COALESCE(p.no_magazine,'f') = 't' THEN 1 ELSE 0 
	END gn_magazine_gewenst,
	CASE
		WHEN p.address_state_id = 2 THEN 1 ELSE 0
	END adres_verkeerd,
	CASE
		WHEN COALESCE(sm.sm_id,0) > 0 THEN 1 ELSE 0
	END DOMI,
		CASE
		WHEN COALESCE(p.recruiting_organisation_id,0) > 0 THEN 1 ELSE 0
	END via_afdeling,
	CASE
		WHEN COALESCE(p.opt_out_letter,'f') = 'f' THEN 0 ELSE 1
	END wenst_geen_post_van_NP,
	CASE
		WHEN COALESCE(p.opt_out,'f') = 'f' THEN 0 ELSE 1
	END wenst_geen_email_van_NP,
	p.iets_te_verbergen nooit_contacteren,
	--CASE WHEN mo.name = 'website' THEN 1 ELSE 0 END via_website,
	--CASE WHEN mo.name <> 'website' THEN 1 ELSE 0 END via_andere,
	CASE WHEN login = 'apiuser' THEN 1 ELSE 0 END via_website,
	CASE WHEN login <> 'apiuser' THEN 1 ELSE 0 END via_andere
	--COALESCE(i.reference,'') OGM	--voor ledencijfers OGM code niet meegeven; geeft verdubbelingen*/
FROM 	_AV_myvar v, res_partner p
	JOIN (SELECT partner_id, SUM(N) N, SUM(G) G, SUM(O1) O1, SUM("5J") "5J", SUM("1-5J") "1-5J", SUM(V) V, SUM(O2) O2 FROM _AV_tempIDs_nieuweleden GROUP BY partner_id) p2 ON p2.partner_id = p.id
	--Voor de ontdubbeling veroorzaakt door meedere lidmaatschapslijnen
	LEFT OUTER JOIN (SELECT MAX(ml.id) ml_id, ml.partner ml_partner FROM membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id WHERE pp.membership_product GROUP BY partner) ml ON ml.ml_partner = p.id
	JOIN membership_membership_line ml2 ON ml2.id = ml.ml_id 
	--land, straat, gemeente info
	JOIN res_country c ON p.country_id = c.id
	LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
	LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
	--herkomst lidmaatschap
	LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
	--aangemaakt door 
	--JOIN res_users u ON u.id = p.create_uid
	--afdeling vs afdeling eigen keuze
	LEFT OUTER JOIN res_partner a ON p.department_id = a.id
	LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	--bank/mandaat info
	--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
	LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
	--facturen info
	LEFT OUTER JOIN account_invoice_line il ON il.id = ml2.account_invoice_line
	LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
	--aanspreking
	--LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
	--parnter info
	LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	--LEFT OUTER JOIN res_partner p6 ON p.relation_partner_id = p6.id
	--wervend lid
	--LEFT OUTER JOIN res_partner p2 ON p.recruiting_member_id = p2.id
	--wervende organisatie
	--LEFT OUTER JOIN res_partner p5 ON p.recruiting_organisation_id = p5.id	
WHERE /*p.id IN (SELECT partner_id, SUM(N) N, SUM(G) G, SUM(O1) O1, SUM("5J") "5J", SUM("1-5J") "1-5J", SUM(V) V, SUM(O2) O2 FROM _AV_tempIDs_nieuweleden GROUP BY partner_id)
	AND*/ p.active = 't'	
	--we tellen voor alle actieve leden
	AND COALESCE(p.deceased,'f') = 'f' 
	--overledenen niet
	AND (COALESCE(ml2.date_cancel,'2099-12-31')) > now()::date
	--opzeggingen met een opzegdatum na vandaag (voor vandaag worden niet meegenomen)
	AND (ml2.state = 'paid'
	-- betaald lidmaatschap
		OR ((ml2.state = 'invoiced' AND COALESCE(sm.sm_id,0) <> 0)
	-- gefactureerd met domi
				OR (ml2.state = 'invoiced' AND COALESCE(i.partner_id,0) <> 0 AND COALESCE(a3.organisation_type_id,0) = 1 )))
	AND COALESCE(a2.id,a.id) = ANY(v.afdeling)
