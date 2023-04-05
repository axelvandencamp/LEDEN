-----------------------------------------
--
-- Te gebruiken voor maandelijkse statistieken

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
	 );
INSERT INTO _AV_myvar VALUES('2023-01-01',	--startdatum
				'2024-12-31'	--einddatum
				);
SELECT * FROM _AV_myvar;
--====================================================================
--====================================================================
SELECT	DISTINCT--COUNT(p.id) _aantal, now()::date vandaag
	p.id database_id,
	CASE
		WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip
		ELSE COALESCE(p.zip,'')
	END postcode,
	CASE 
		WHEN c.id = 21 THEN cc.name ELSE COALESCE(p.city,'')
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
	COALESCE(a.id,0) Afdeling,
	CASE WHEN COALESCE(p5.id,0) > 0 AND p.membership_start >= v.startdatum THEN 1 ELSE 0 END nieuw_via_afdeling,
	COALESCE(r.id,0) regionale,
	CASE WHEN COALESCE(mo.id,0) > 0 AND p.membership_start >= v.startdatum THEN mo.id ELSE 0 END herkomst_lidmaatschap,
	CASE WHEN COALESCE(p5.id,0) > 0 AND p.membership_start >= v.startdatum THEN p5.id ELSE 0 END wervende_organisatie,
	CASE WHEN p.membership_start >= v.startdatum THEN 1 ELSE 0 END nieuw_lid,
	CASE WHEN p.membership_state = 'free' THEN 1 ELSE 0 END gratis_lid,
	CASE WHEN COALESCE(sm.sm_id,0) > 0 THEN 1 ELSE 0 END DOMI,
	CASE WHEN login = 'apiuser' AND p.membership_start >= v.startdatum THEN 1 ELSE 0 END via_website,
	CASE WHEN COALESCE(COALESCE(p.email_work,p.email),'_') = '_' THEN 0 ELSE 1 END email,
	CASE WHEN COALESCE(p.phone,'_') <> '_' THEN 1
		WHEN COALESCE(p.phone_work,'_') <> '_' THEN 1
		WHEN COALESCE(p.mobile,'_') <> '_' THEN 1 ELSE 0 
	END telefoonnr,
	CASE WHEN COALESCE(p.address_state_id,0) = 2 THEN 1 ELSE 0 END foutadres/*,
	CASE WHEN login <> 'apiuser' THEN 1 ELSE 0 END via_andere,
	p.gender AS geslacht,
	p.birthday,
	EXTRACT(YEAR from AGE(p.birthday)) leeftijd,
	_crm_land(c.id) land,
	COALESCE(cc.zip,'_')||ccs.id::text||COALESCE(p.street_nbr::text,'_')||COALESCE(p.street_bus::text,'_') adres_id,
		p.membership_state huidige_lidmaatschap_status,
	COALESCE(p.membership_start,p.create_date::date) aanmaak_datum,
	p.membership_start Lidmaatschap_startdatum, 
	p.membership_stop Lidmaatschap_einddatum,  
	p.membership_pay_date betaaldatum,
	p.membership_renewal_date hernieuwingsdatum,
	p.membership_end recentste_einddatum_lidmaatschap,
	p.membership_cancel membership_cancel,
	_crm_opzegdatum_membership(p.id) opzegdatum_LML,
	CASE	--SELECT * FROM res_partner_corporation_type
			WHEN p.organisation_type_id IN (1,3,5,7,8,16) THEN 'Intern'
			WHEN p.corporation_type_id BETWEEN 1 AND 12 THEN 'Vennootschap'
			WHEN p.corporation_type_id = 13 THEN 'Publiekrechterlijk'
			WHEN p.corporation_type_id IN (15,16) THEN 'Stichting'
			WHEN p.corporation_type_id = 17 THEN 'Vereniging'
			ELSE 'Private persoon'
	END rechtspersoon,
	p.active,
		CASE
		WHEN p.address_state_id = 2 THEN 1 ELSE 0
	END adres_verkeerd,
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
	p.iets_te_verbergen nooit_contacteren*/
FROM 	_av_myvar v, res_partner p
	--Voor de ontdubbeling veroorzaakt door meedere lidmaatschapslijnen
	LEFT OUTER JOIN (SELECT * FROM _av_myvar v, membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id WHERE  ml.date_to BETWEEN v.startdatum and v.einddatum AND pp.membership_product) ml ON ml.partner = p.id
	--idem: versie voor jaarwisseling (januari voor vorige jaar)
	--LEFT OUTER JOIN (SELECT * FROM _av_myvar v, membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id WHERE  ml.state = 'paid' AND ml.date_to BETWEEN v.startdatum and v.einddatum AND pp.membership_product) ml ON ml.partner = p.id
	--land, straat, gemeente info
	JOIN res_country c ON p.country_id = c.id
	LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
	LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
	--herkomst lidmaatschap
	LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
	--aangemaakt door 
	JOIN res_users u ON u.id = p.create_uid
	--afdeling & afdeling eigen keuze
	LEFT OUTER JOIN res_partner a ON a.id = COALESCE(p.department_choice_id,p.department_id)
	--LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	--regionale
	LEFT OUTER JOIN res_partner r ON a.partner_up_id = r.id
	--bank/mandaat info
	--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
	LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
	--facturen info
	LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
	LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
	--parnter info
	/*LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	LEFT OUTER JOIN res_partner p6 ON p.relation_partner_id = p6.id*/
	--wervend lid
	--LEFT OUTER JOIN res_partner p2 ON p.recruiting_member_id = p2.id
	--wervende organisatie
	LEFT OUTER JOIN res_partner p5 ON p.recruiting_organisation_id = p5.id
--=============================================================================
WHERE 	p.active = 't'	
	--we tellen voor alle actieve leden
	--AND COALESCE(p.deceased,'f') = 'f' 
	--overledenen niet
	--AND COALESCE(p.free_member,'f') = 'f'
	--gratis leden niet
	AND p.membership_state IN ('paid','invoiced','free') -- **** uitschakelen voor jaarovergang ****
	--AND p.membership_start < '2021-01-01' -- JAAROVERGANG
	--AND (ml.date_from BETWEEN v.startdatum and v.einddatum OR v.startdatum BETWEEN ml.date_from AND ml.date_to) AND ml.membership_id IN (2,5,6,7,205,206,207,208)
