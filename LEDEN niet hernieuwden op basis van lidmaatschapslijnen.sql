--------------------------------------------------------
-- aangemaakt: 02/03/2016
-- laatste aanpassing: 02/03/2016
--------------------------------------------------------
DROP TABLE IF EXISTS myvar;
SELECT 
	--'2016-12-31'::date AS cutoff_datum,
	'2024-01-01'::date AS startdatum_vorigjaar,
	'2024-12-31'::date AS einddatum_vorigjaar,
	'2025-01-01'::date AS startdatum,
	'2025-12-31'::date AS einddatum,  --naar volgend jaar verzetten vanaf 01/07
	'248514'::numeric AS afdeling --(aartselaar 248646; hobokense polder 248569; gent vzw 248514)
INTO TEMP TABLE myvar;
SELECT * FROM myvar;
--------------------------------------------------------
--CREATE TEMP TABLE
DROP TABLE IF EXISTS temp_NietHernieuwden;

CREATE TEMP TABLE temp_NietHernieuwden (
	Partner_id numeric,
	Lidnummer text,
	Lidmaatschapslijn integer,
	Aanschrijving text,
	Voornaam text,
	Naam text,
	Straat text,
	Huisnummer text,
	Bus text,
	Postcode text,
	Woonplaats text,
	Provincie text,
	Land text,
	Email text,
	--email_werk text, --enkel voor belactie
	telefoonnr text, --enkel voor belactie
	gsm text, --enkel voor belactie
	/*street_id integer, --enkel nodig voor update stratenlijst dump gent
	zip_id integer,
	country_id integer,
	crab_used boolean,*/
	pb_bic character varying, 
	pb_bank_rek character varying,
	sm_mandaat_ref character varying,
	website_gebruiker text,
	suppressed text,
	Aanmaakdatum date,
	Startdatum date,
	Einddatum date,
	Recentste_einddatum date,
	Betaal_datum date,
	Opzegdatum date,
	lml_opgzegdatum date,
	Lidmaatschap_status text,
	Afdeling text,
	Herkomst_lidmaatschap text,
	Derde_betaler text,
	wenst_geen_post_van_NP numeric,
	wenst_geen_email_van_NP numeric,
	nooit_contacteren text,
	OGM text,
	pom_paylink text,
	bedrag numeric,
	product text,
	type_digitaal_post text,
	type_digitaal_NPblad text);
--------------------------------------------------------
INSERT INTO temp_NietHernieuwden (	
	SELECT DISTINCT p.id,
		p.membership_nbr lidnummer,
		ml2.id,
		CASE WHEN COALESCE(p.first_name,'natuurliefhebber') = '' THEN 'natuurliefhebber' ELSE COALESCE(p.first_name,'natuurliefhebber') END aanschrijving,
		p.first_name as voornaam,
		p.last_name as achternaam,
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
		END zip,
		CASE 
			WHEN c.id = 21 THEN cc.name ELSE p.city 
		END gemeente,
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
		COALESCE(COALESCE(p.email,p.email_work),'') email, -- in comment voor belactie
		/* enkel voor belactie
		p.email,
		p.email_work,*/
		--COALESCE(p.phone_work,p.phone) telefoonnr,
		CASE
			WHEN substr(COALESCE(p.phone_work,p.phone),1,2) = '00' THEN '+'||regexp_replace(substr(COALESCE(p.phone_work,p.phone),3,length(COALESCE(p.phone_work,p.phone))), '[^0-9]+', '', 'g')
			WHEN substr(COALESCE(p.phone_work,p.phone),1,3) = '+32' THEN '+'||regexp_replace(COALESCE(p.phone_work,p.phone), '[^0-9]+', '', 'g')
			WHEN substr(COALESCE(p.phone_work,p.phone),1,1) = '0' THEN '+32'||regexp_replace(substr(COALESCE(p.phone_work,p.phone),2,length(COALESCE(p.phone_work,p.phone))), '[^0-9]+', '', 'g')
			WHEN LENGTH(regexp_replace(COALESCE(p.phone_work,p.phone), '[^0-9]+', '', 'g')) > 10 THEN '+'||regexp_replace(COALESCE(p.phone_work,p.phone), '[^0-9]+', '', 'g')
			WHEN LENGTH(COALESCE(p.phone_work,p.phone)) > 0 THEN '+32'||regexp_replace(COALESCE(p.phone_work,p.phone), '[^0-9]+', '', 'g')
			ELSE COALESCE(p.phone_work,p.phone)
		END telefoonnr,
		CASE
			WHEN substr(p.mobile,1,2) = '00' THEN '+'||regexp_replace(substr(p.mobile,3,length(p.mobile)), '[^0-9]+', '', 'g')
			WHEN substr(p.mobile,1,3) = '+32' THEN '+'||regexp_replace(p.mobile, '[^0-9]+', '', 'g')
			WHEN substr(p.mobile,1,1) = '0' THEN '+32'||regexp_replace(substr(p.mobile,2,length(p.mobile)), '[^0-9]+', '', 'g')
			WHEN LENGTH(regexp_replace(p.mobile, '[^0-9]+', '', 'g')) > 10 THEN '+'||regexp_replace(p.mobile, '[^0-9]+', '', 'g')
			WHEN LENGTH(p.mobile) > 0 THEN '+32'||regexp_replace(p.mobile, '[^0-9]+', '', 'g')
			ELSE p.mobile
		END  gsm,
		--p.mobile gsm,
		--*/
		/*p.street_id, --enkel nodig voor update stratenlijst dump gent
		p.zip_id,
		p.country_id,
		p.crab_used,*/
		--/* voor "VERZENDLIJST hernieuwingen" met evaluatie websitegebruikers en suppressionlist; anders lege tabellen voorzien;
		pb_bic, 
		pb_bank_rek,
		sm_mandaat_ref,
		CASE WHEN COALESCE(w.partner_id,0) = 0 THEN 'neen' ELSE 'ja' END website_gebruiker,
	 	CASE WHEN COALESCE(s.emailaddress,'_') = '_' THEN 'neen'  
			 WHEN COALESCE(s.emailaddress,'_') = '_' THEN 'neen' ELSE 'ja' END suppressed,
		COALESCE(p.create_date::date,p.membership_start) aanmaak_datum,
		p.membership_start, 
		p.membership_stop, 
		p.membership_end, 
		p.membership_pay_date, 
		p.membership_cancel,
		NULL::date lml_opgzegdatum,
		p.membership_state,
		CASE WHEN COALESCE(COALESCE(a2.name,a.name),'Natuurpunt') = '' THEN 'Natuurpunt' ELSE COALESCE(COALESCE(a2.name,a.name),'Natuurpunt') END Afdeling,
		mo.name herkomst_lidmaatschap,
		p.third_payer_id,
		CASE
			WHEN COALESCE(p.opt_out_letter,'f') = 'f' THEN 0 ELSE 1
		END wenst_geen_post_van_NP,
		CASE
			WHEN COALESCE(p.opt_out,'f') = 'f' THEN 0 ELSE 1
		END wenst_geen_email_van_NP,
		p.iets_te_verbergen nooit_contacteren,
		NULL OGM,
		NULL pom_paylink,
		NULL::numeric bedrag,
		NULL product,
		CASE WHEN COALESCE(p.opt_out_letter,'f') = 't' THEN 'geen post gewenst'
			WHEN COALESCE(p.address_state_id,0) = 2 THEN 'adres verkeerd'
			ELSE '' END type_digitaal_post,
		CASE WHEN COALESCE(p.no_magazine,'f') = 't' THEN 'geen magazine gewenst'
			WHEN COALESCE(p.address_state_id,0) = 2 THEN 'adres verkeerd'
			ELSE '' END type_digitaal_NPblad
	FROM	myvar v, res_partner p
		JOIN
		(
			SELECT * 
			FROM myvar v, membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id
			WHERE  (ml.date_to BETWEEN v.startdatum_vorigjaar and v.einddatum_vorigjaar OR v.einddatum_vorigjaar BETWEEN ml.date_from AND ml.date_to) 
				AND pp.membership_product
		) ml1 ON ml1.partner = p.id
		LEFT OUTER JOIN
		(
			SELECT MAX(ml.id) id, ml.partner 
			FROM myvar v, membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id
			WHERE  (ml.date_to BETWEEN v.startdatum and v.einddatum OR v.einddatum BETWEEN ml.date_from AND ml.date_to) 
				AND pp.membership_product
			GROUP BY ml.partner
		) ml2 ON ml2.partner = ml1.partner
		LEFT OUTER JOIN marketing._av_temp_websitegebruikers w ON w.partner_id = p.id
		LEFT OUTER JOIN marketing._av_temp_suppressionlist s ON LOWER(s.emailaddress) = LOWER(p.email) 
		LEFT OUTER JOIN marketing._av_temp_suppressionlist s2 ON LOWER(s2.emailaddress) = LOWER(p.email_work)

		
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--regionale
		LEFT OUTER JOIN res_partner r ON r.id = COALESCE(a2.partner_up_id,a.partner_up_id)
		--bank/mandaat info
		--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
		LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, pb.bank_bic pb_bic, pb.acc_number pb_bank_rek, sm.unique_mandate_reference sm_mandaat_ref FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id

	WHERE p.active AND COALESCE(p.deceased,'f') = 'f'
		AND p.membership_state = 'wait_member'
		--AND COALESCE(a2.id,a.id) = v.afdeling
		--AND r.id = 15192
	);
--OGM toevoegen
UPDATE temp_NietHernieuwden nh
SET OGM = (SELECT i.reference 
		FROM membership_membership_line ml 
			JOIN account_invoice_line il ON ml.account_invoice_line = il.id 
			JOIN account_invoice i ON i.id = il.invoice_id
			JOIN product_product pp ON pp.id = il.product_id
		WHERE nh.lidmaatschapslijn = ml.id);
--pom_paylink toevoegen
UPDATE temp_NietHernieuwden nh
SET pom_paylink = (SELECT 'https://pay.pom.be/'||pom.pom_paylink_short
		FROM pom_paylink pom
			JOIN account_invoice i ON i.pom_paylink_id = pom.id
			JOIN account_invoice_line il ON i.id = il.invoice_id
			--JOIN account_invoice i ON i.id = il.invoice_id
			JOIN membership_membership_line ml ON il.id = ml.account_invoice_line
		WHERE nh.lidmaatschapslijn = ml.id);
		
		--SELECT * FROM pom_paylink
--bedrag toevoegen
UPDATE temp_NietHernieuwden nh
SET bedrag = (SELECT i.amount_total 
		FROM membership_membership_line ml 
			JOIN account_invoice_line il ON ml.account_invoice_line = il.id 
			JOIN account_invoice i ON i.id = il.invoice_id
			JOIN product_product pp ON pp.id = il.product_id
		WHERE nh.lidmaatschapslijn = ml.id);
--product toevoegen
UPDATE temp_NietHernieuwden nh
SET product = (SELECT pp.name_template 
		FROM membership_membership_line ml 
			JOIN account_invoice_line il ON ml.account_invoice_line = il.id 
			JOIN account_invoice i ON i.id = il.invoice_id
			JOIN product_product pp ON pp.id = il.product_id
		WHERE nh.lidmaatschapslijn = ml.id);
--lidmaatschapslijn opzegdatum toevoegen
UPDATE temp_NietHernieuwden nh
SET lml_opgzegdatum = (SELECT ml.date_cancel
			FROM membership_membership_line ml
			WHERE ml.id = nh.lidmaatschapslijn);
---------------------------------------
SELECT * /*count(partner_id)*/ FROM  temp_NietHernieuwden nh WHERE partner_id IN (142815,209021,133586,165065,21345,112483,119978,122886,126299,135175,148229,171130,186507,202659,226924,302422,397836)
SELECT Partner_id, pb_bic, pb_bank_rek, sm_mandaat_ref FROM  temp_NietHernieuwden nh
);
--verzendlijst via POST
SELECT * FROM temp_NietHernieuwden nh 
WHERE (nh.website_gebruiker = 'neen') OR (nh.website_gebruiker = 'ja' AND nh.suppressed = 'ja')
	AND COALESCE(nooit_contacteren,'false') = 'false'
	--AND COALESCE(derde_betaler,'_') = '_'
--verzendlijst via MAIL
SELECT * FROM temp_NietHernieuwden nh 
WHERE (nh.website_gebruiker = 'ja' AND nh.suppressed = 'neen')
	AND COALESCE(nooit_contacteren,'false') = 'false'
	--AND COALESCE(derde_betaler,'_') = '_'
--verzendlijst: te hernieuwen met email adres en geregistreerde gebruiker
SELECT * FROM  temp_NietHernieuwden nh
WHERE COALESCE(email,'_') <> '_' AND website_gebruiker = 'ja' AND suppressed = 'neen'
--verzendlijst: te hernieuwen met email adres en NIET geregistreerde gebruiker
SELECT * FROM  temp_NietHernieuwden nh
WHERE COALESCE(email,'_') <> '_' AND website_gebruiker = 'neen' --AND suppressed = 'neen'
--=====================================
--TEST
/*
SELECT * FROM  temp_NietHernieuwden nh WHERE partner_id = 268969

SELECT ml.membership_id, ml.partner, ml.date_from, ml.date_to, * FROM membership_membership_line ml WHERE partner = 268969

SELECT MAX(ml.id) id, ml.partner
SELECT ml.id, ml.partner, ml.date_from, ml.date_to, ml.membership_id
FROM myvar v, membership_membership_line ml --JOIN product_product pp ON pp.id = ml.membership_id
WHERE  (ml.date_to BETWEEN v.startdatum and v.einddatum OR v.einddatum BETWEEN ml.date_from AND ml.date_to) 
	AND pp.membership_product
	AND ml.partner = 268969	
GROUP BY ml.partner
*/
/*
SELECT ml.id, i.number, i.reference, i.amount_total, pp.name_template
	FROM membership_membership_line ml
		JOIN account_invoice_line il ON ml.account_invoice_line = il.id 
		JOIN account_invoice i ON i.id = il.invoice_id
		JOIN product_product pp ON pp.id = il.product_id
	WHERE ml.id IN (SELECT lidmaatschapslijn FROM temp_NietHernieuwden nh)
*/