-----------------------------------------
--
-- Te gebruiken voor maandelijkse statistieken
-- - leden per provincie
-- - leden per afdeling
-- - nieuwwe leden per wervende afdeling
--
-- OPMERKING
-- - voor ledencijfers "OGM" in comment laten; geeft verdubbelingen
-- - ook alle "ml." velden weglaten om zelfde reden
-----------------------------------------

--=================================================================
--
-- REGEL voor ivm uitsluiting opgezegden herzien (of procedure van opzegging)
--
--=================================================================
--SET VARIABLES
DROP TABLE IF EXISTS _AV_myvar;
CREATE TEMP TABLE _AV_myvar 
	(startdatum DATE, einddatum DATE
	 ,afdeling NUMERIC, postcode TEXT, herkomst_lidmaatschap NUMERIC, wervende_organisatie NUMERIC, test_id NUMERIC
	 );

INSERT INTO _AV_myvar VALUES('2020-01-01',	--startdatum
				'2021-12-31',	--einddatum
				248494, --afdeling 	
				'2260', --postcode
				494,  	--numeric 
				248585,	--wervende_organisatie
				'16382'	--numeric
				);
SELECT * FROM _AV_myvar;
--====================================================================
--====================================================================
SELECT	DISTINCT--COUNT(p.id) _aantal, now()::date vandaag
	p.id database_id, 
	p.membership_nbr lidnummer, 
	/*CASE
		WHEN p.gender = 'M' THEN 'Dhr.'
		WHEN p.gender = 'V' THEN 'Mevr.'
		ELSE pt.shortcut
	END aanspreking,*/
	p.gender AS geslacht,
	--p.name as partner,
	p.first_name as voornaam,
	p.last_name as achternaam,
	CASE
		WHEN COALESCE(p6.id,0)>0 AND p6.membership_state = 'none' AND CHAR_LENGTH(p6.first_name) > 0 THEN p.first_name || ' en ' || p6.first_name ELSE p.first_name
	END voornaam_lidkaart,
	CASE
		WHEN COALESCE(p6.id,0)>0 AND p6.membership_state = 'none' AND CHAR_LENGTH(p6.last_name) > 0 THEN p.last_name || ' - ' || p6.last_name ELSE p.last_name
	END achternaam_lidkaart,
	p.birthday,
	EXTRACT(YEAR from AGE(p.birthday)) leeftijd,
	p.street2 building,
	CASE
		WHEN c.id = 21 AND p.crab_used = 'true' THEN ccs.name
		ELSE p.street
	END straat,
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
	--COALESCE(ml.id::text,'') ml_id,
	COALESCE(p.phone_work,p.phone) telefoonnr,
	p.mobile gsm,
	COALESCE(COALESCE(a2.name,a.name),'onbekend') Afdeling,
	COALESCE(mo.name,'') herkomst_lidmaatschap,
	p.membership_state huidige_lidmaatschap_status,
	COALESCE(p.create_date::date,p.membership_start) aanmaak_datum,
	--ml.date_from lml_date_from,
	p.membership_start Lidmaatschap_startdatum, 
	p.membership_stop Lidmaatschap_einddatum,  
	p.membership_pay_date betaaldatum,
	p.membership_renewal_date hernieuwingsdatum,
	p.membership_end recentste_einddatum_lidmaatschap,
	p.membership_cancel membership_cancel,
	_crm_opzegdatum_membership(p.id) opzegdatum_LML,
	p.active,
	p2.name wervend_lid,
	p2.membership_nbr wl_lidnummer,
	p5.name wervende_organisatie,
	mm1.name tijdschrift1,
	mm2.name tijdschrift2,
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
		WHEN p.membership_start >= v.startdatum THEN 1 ELSE 0
	END nieuw_lid,
	CASE
		WHEN p.membership_start < v.startdatum THEN 1 ELSE 0
	END hernieuwing,
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
	--COALESCE(i.reference,'') OGM	--voor ledencijfers OGM code niet meegeven; geeft verdubbelingen
FROM 	_av_myvar v, res_partner p
	--Voor de ontdubbeling veroorzaakt door meedere lidmaatschapslijnen
	--LEFT OUTER JOIN (SELECT * FROM _av_myvar v, membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id WHERE  ml.date_to BETWEEN v.startdatum and v.einddatum AND pp.membership_product) ml ON ml.partner = p.id
	--idem: versie voor jaarwisseling (januari voor vorige jaar)
	LEFT OUTER JOIN (SELECT * FROM _av_myvar v, membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id WHERE  ml.state = 'paid' AND ml.date_to BETWEEN v.startdatum and v.einddatum AND pp.membership_product) ml ON ml.partner = p.id
	--land, straat, gemeente info
	JOIN res_country c ON p.country_id = c.id
	LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
	LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
	--herkomst lidmaatschap
	LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
	--aangemaakt door 
	JOIN res_users u ON u.id = p.create_uid
	--afdeling vs afdeling eigen keuze
	LEFT OUTER JOIN res_partner a ON p.department_id = a.id
	LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	--bank/mandaat info
	--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
	LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
	--facturen info
	LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
	LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
	--aanspreking
	LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
	--parnter info
	LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	LEFT OUTER JOIN res_partner p6 ON p.relation_partner_id = p6.id
	--wervend lid
	LEFT OUTER JOIN res_partner p2 ON p.recruiting_member_id = p2.id
	--wervende organisatie
	LEFT OUTER JOIN res_partner p5 ON p.recruiting_organisation_id = p5.id
	--tijdschriften
	LEFT OUTER JOIN mailing_mailing mm1 ON mm1.id = p.periodical_1_id
	LEFT OUTER JOIN mailing_mailing mm2 ON mm2.id = p.periodical_2_id
--=============================================================================
WHERE 	p.active = 't'	
	--we tellen voor alle actieve leden
	AND COALESCE(p.deceased,'f') = 'f' 
	--overledenen niet
	AND COALESCE(p.free_member,'f') = 'f'
	--gratis leden niet
	AND p.membership_state IN ('paid','invoiced') -- **** uitschakelen voor jaarovergang ****
	--AND (ml.date_from BETWEEN v.startdatum and v.einddatum OR v.startdatum BETWEEN ml.date_from AND ml.date_to) AND ml.membership_id IN (2,5,6,7,205,206,207,208)
	--enkel lidmaatschapsproduct lijnen met een einddatum in 2015
	--AND p.membership_start < '2013-01-01' 
	--lidmaatschap start voor 01/01/2013
	--AND NOT((COALESCE(ml.date_cancel,'2099-12-31')) > now()::date) -- AND ml.date_to < '2019-12-31') -- **** specifiek voor jaarovergang ****
	--opzeggingen met een opzegdatum na vandaag (voor vandaag worden niet meegenomen)
	--AND COALESCE(p.create_date::date,p.membership_start) < '2020-01-01'  -- **** specifiek voor jaarovergang ****
	--AND (ml.state = 'paid'
	-- betaald lidmaatschap
	--	OR ((ml.state = 'invoiced' AND COALESCE(sm.sm_id,0) <> 0)
	-- gefactureerd met domi
	--			OR (ml.state = 'invoiced' AND COALESCE(i.partner_id,0) <> 0 AND COALESCE(a3.organisation_type_id,0) = 1 )))
	-- extra controle op startdatum van het lidmaatschap (enkel nodig bij jaarovergang om leden in het nieuwe jaar gecreëerd af te trekken van de "huidige toestand" van het vorige jaar)
	--AND p.membership_start < '2017-01-01'
	--bepaald ID
	--AND p.id = v.test_id
	-- gefactureerd en betaald via afdeling
	--AND 	(	--specifiek voor vraag "Natuur.koepel"
	--	mo.id IN (644,642,643,645,650,651,652,653,654,655,656,658,659,660,663,664,667,668,669)
	--	OR
	--	COALESCE(p.recruiting_organisation_id,0) IN (248509,248659,248643,248589,248546,248502,248622,248588,248574,248520,17130)
	--	)
	--per afdeling
	--AND COALESCE(a2.id,a.id) = v.afdeling
	--per postcode
	--AND cc.zip = v.postcode
	--AND cc.zip IN ('1540','1547','1570')
	--enkel nieuwe
	--AND p.membership_start >= v.startdatum
	--aangemaakt via afdeling
	--AND COALESCE(p.recruiting_organisation_id,0) > 0
	--aangemaakt door specifieke afdeling
	--AND COALESCE(p.recruiting_organisation_id,0) = v.afdeling
	--herkomst lidmaatschap
	--AND LOWER(mo.name) LIKE '%website%'
	--herkomst lidmaatschap (ID)
	--AND mo.id = v.herkomst_lidmaatschap
	--specifiek op status en voor 'apiuser'
	--AND p.membership_state = v.status AND u.login = 'apiuser'
	--Wervende Afdeling (andere organisatie)
	--AND p5.id = v.wervende_organisatie 
	--Leeftijd
	--AND EXTRACT(YEAR from AGE(p.birthday)) > 65
--=============================================================================
--GRATIS LEDEN TOEVOEGEN
UNION ALL
--=============================================================================
SELECT	DISTINCT--COUNT(p.id) _aantal, now()::date vandaag
	p.id database_id, 
	p.membership_nbr lidnummer, 
	/*CASE
		WHEN p.gender = 'M' THEN 'Dhr.'
		WHEN p.gender = 'V' THEN 'Mevr.'
		ELSE pt.shortcut
	END aanspreking,*/
	p.gender AS geslacht,
	--p.name as partner,
	p.first_name as voornaam,
	p.last_name as achternaam,
	CASE
		WHEN COALESCE(p6.id,0)>0 AND p6.membership_state = 'none' AND CHAR_LENGTH(p6.first_name) > 0 THEN p.first_name || ' en ' || p6.first_name ELSE p.first_name
	END voornaam_lidkaart,
	CASE
		WHEN COALESCE(p6.id,0)>0 AND p6.membership_state = 'none' AND CHAR_LENGTH(p6.last_name) > 0 THEN p.last_name || ' - ' || p6.last_name ELSE p.last_name
	END achternaam_lidkaart,
	p.birthday,
	EXTRACT(YEAR from AGE(p.birthday)) leeftijd,
	p.street2 building,
	CASE
		WHEN c.id = 21 AND p.crab_used = 'true' THEN ccs.name
		ELSE p.street
	END straat,
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
	p.email email,
	--COALESCE(ml.id::text,'') ml_id,
	COALESCE(p.phone_work,p.phone) telefoonnr,
	p.mobile gsm,
	COALESCE(COALESCE(a2.name,a.name),'onbekend') Afdeling,
	COALESCE(mo.name,'') herkomst_lidmaatschap,
	p.membership_state huidige_lidmaatschap_status,
	--NULL::date lml_date_from,
	COALESCE(p.create_date::date,p.membership_start) aanmaak_datum,
	p.membership_start Lidmaatschap_startdatum, 
	p.membership_stop Lidmaatschap_einddatum,  
	p.membership_pay_date betaaldatum,
	p.membership_renewal_date hernieuwingsdatum,
	p.membership_end recentste_einddatum_lidmaatschap,
	p.membership_cancel membership_cancel,
	_crm_opzegdatum_membership(p.id) opzegdatum_LML,
	p.active,
	p2.name wervend_lid,
	p2.membership_nbr wl_lidnummer,
	p5.name wervende_organisatie,
	mm1.name tijdschrift1,
	mm2.name tijdschrift2,
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
		WHEN p.membership_start >= v.startdatum THEN 1 ELSE 0
	END nieuw_lid,
	CASE
		WHEN p.membership_start < v.startdatum THEN 1 ELSE 0
	END hernieuwing,
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
	--NULL as OGM
FROM 	_av_myvar v, res_partner p
	--Voor de ontdubbeling veroorzaakt door meedere lidmaatschapslijnen
	--LEFT OUTER JOIN (SELECT * FROM myvar v, membership_membership_line ml WHERE  ml.date_to BETWEEN v.startdatum and v.einddatum AND ml.membership_id IN (2,5,6,7,205,206,207,208)) ml ON ml.partner = p.id
	--land, straat, gemeente info
	JOIN res_country c ON p.country_id = c.id
	LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
	LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
	--herkomst lidmaatschap
	LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
	--aangemaakt door 
	JOIN res_users u ON u.id = p.create_uid
	--afdeling vs afdeling eigen keuze
	LEFT OUTER JOIN res_partner a ON p.department_id = a.id
	LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	--bank/mandaat info
	--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
	LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
	--facturen info
	--LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
	--LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
	--aanspreking
	LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
	--parnter info
	--LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	LEFT OUTER JOIN res_partner p6 ON p.relation_partner_id = p6.id
	--wervend lid
	LEFT OUTER JOIN res_partner p2 ON p.recruiting_member_id = p2.id
	--wervende organisatie
	LEFT OUTER JOIN res_partner p5 ON p.recruiting_organisation_id = p5.id
	--tijdschriften
	LEFT OUTER JOIN mailing_mailing mm1 ON mm1.id = p.periodical_1_id
	LEFT OUTER JOIN mailing_mailing mm2 ON mm2.id = p.periodical_2_id
--=============================================================================
WHERE 	p.active = 't'	
	--we tellen voor alle actieve leden
	AND COALESCE(p.deceased,'f') = 'f' 
	--overledenen niet
	AND COALESCE(p.free_member,'f') = 't'
	--gratis leden niet
	--per afdeling
	--AND COALESCE(a2.id,a.id) = v.afdeling
	--per postcode
	--AND cc.zip = v.postcode
	--AND cc.zip IN ('1540','1547','1570')
	--enkel nieuwe
	--AND p.membership_start >= v.startdatum
	--aangemaakt via afdeling
	--AND COALESCE(p.recruiting_organisation_id,0) > 0
	--aangemaakt door specifieke afdeling
	--AND COALESCE(p.recruiting_organisation_id,0) = v.afdeling
	--herkomst lidmaatschap
	--AND LOWER(mo.name) LIKE '%lampiris%'
	--herkomst lidmaatschap (ID)
	--AND mo.id = v.herkomst_lidmaatschap
	--Wervende Afdeling (andere organisatie)
	--AND p5.id = v.wervende_organisatie
	--Leeftijd
	--AND EXTRACT(YEAR from AGE(p.birthday)) > 65
	--bepaald ID
	--AND p.id = v.test_id
