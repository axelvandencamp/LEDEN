--SET VARIABLES
DROP TABLE IF EXISTS _AV_myvar;
CREATE TEMP TABLE _AV_myvar 
	(einddatum DATE
		 );

INSERT INTO _AV_myvar VALUES('2021-12-31'	--einddatum
				);
SELECT * FROM _AV_myvar;
----------------------------------------------
SELECT 
	p.id partner_id,
	p.membership_nbr lidnummer, 
	p.first_name as voornaam,
	p.last_name as achternaam,
	p.street2 huisnaam,
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
	_crm_land(c.id) land,
	p.email,
	--COALESCE(ml.id::text,'') ml_id,
	COALESCE(p.phone_work,p.phone) telefoonnr,
	p.mobile gsm,
	p.membership_state huidige_lidmaatschap_status,
	r.id reg,
	COALESCE(p.membership_start,p.create_date::date) aanmaak_datum,
	--ml.date_from lml_date_from,
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
	CASE
		WHEN p.address_state_id = 2 THEN 1 ELSE 0
	END adres_verkeerd,
	CASE
		WHEN COALESCE(p.opt_out_letter,'f') = 'f' THEN 0 ELSE 1
	END wenst_geen_post_van_NP,
	CASE
		WHEN COALESCE(p.opt_out,'f') = 'f' THEN 0 ELSE 1
	END wenst_geen_email_van_NP,
	p.iets_te_verbergen nooit_contacteren
FROM 	_av_myvar v, res_partner p
	--land, straat, gemeente info
	JOIN res_country c ON p.country_id = c.id
	LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
	LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
	--afdeling vs afdeling eigen keuze
	LEFT OUTER JOIN res_partner a ON p.department_id = a.id
	LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	--regionale
	LEFT OUTER JOIN res_partner r ON r.id = COALESCE(a2.partner_up_id,a.partner_up_id)
WHERE 	p.membership_end = v.einddatum
	AND p.active = 't'	
	--we tellen voor alle actieve leden
	AND COALESCE(p.deceased,'f') = 'f' 
	--overledenen niet
	AND NOT(p.membership_state IN ('paid','invoiced','free'))	
	--AND r.id = 15192