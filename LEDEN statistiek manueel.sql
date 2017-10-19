-- en ook hier een github test (mag later weg)
 --
 --SET VARIABLES
DROP TABLE IF EXISTS myvar;
SELECT 
	'2017-01-01'::date AS startdatum 
	,'2018-12-31'::date AS einddatum  --vanaf 01/07 lid tot einde volgend jaar
	,'2017-02-01'::date AS cutoffdate --te gebruiken bij jaarovergang om nieuwe leden nieuwe jaar af te trekken van tellen voorbije jaar
	,'1999-01-01'::date AS basedatum
	,'102324'::numeric AS ledenaantal_vorigjaar --eind 2015 
	--,'97362'::numeric AS ledenaantal_vorigjaar --eind 2015 
	--,'95163'::numeric AS ledenaantal_vorigjaar --einde 2014
	--,'14-221-295'::text AS uittreksel
INTO TEMP TABLE myvar;
SELECT * FROM myvar;

-----------------------------------------
-- TELLING LEDEN VIA WEBSITE TOEVOEGEN --
-----------------------------------------

--CREATE TEMP TABLE
DROP TABLE IF EXISTS tempLEDEN_statistiek_manueel;

CREATE TEMP TABLE tempLEDEN_statistiek_manueel (
	ID numeric,
	Naam text,
	Volgnummer numeric,
	Categorie text,
	Aantal numeric,
	Datum_gelopen date,
	Opmerking text);
----------------------------------------
-- 1/ LEDEN aantal ---------------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	1, 'Leden: ', 1 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, '"Leden" en "Gratis leden" moeten samen geteld worden.'
	FROM 	myvar v, res_partner p
		--Voor de ontdubbeling veroorzaakt door meedere lidmaatschapslijnen
		LEFT OUTER JOIN (SELECT * FROM myvar v, membership_membership_line ml WHERE  ml.date_to BETWEEN v.startdatum and v.einddatum AND ml.membership_id IN (2,5,6,7,205,206,207,208)) ml ON ml.partner = p.id
		--land, straat, gemeente info
		--JOIN res_country c ON p.country_id = c.id
		--LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		--LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		--LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--aangemaakt door 
		--JOIN res_users u ON u.id = p.create_uid
		--afdeling vs afdeling eigen keuze
		--LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		--LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--bank/mandaat info
		--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
		LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
		--facturen info
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		--aanspreking
		--LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--parnter info
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
		--wervend lid
		--LEFT OUTER JOIN res_partner p2 ON p.recruiting_member_id = p2.id
		--wervende organisatie
		--LEFT OUTER JOIN res_partner p5 ON p.recruiting_organisation_id = p5.id
	WHERE 	p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		AND COALESCE(p.free_member,'f') = 'f'
		--gratis leden niet
		AND (ml.date_from BETWEEN v.startdatum and v.einddatum OR v.startdatum BETWEEN ml.date_from AND ml.date_to) AND ml.membership_id IN (2,5,6,7,205,206,207,208)
		--enkel lidmaatschapsproduct lijnen met een einddatum in 2015
		--AND p.membership_start < '2013-01-01' 
		--lidmaatschap start voor 01/01/2013
		AND (COALESCE(ml.date_cancel,'2099-12-31')) > now()::date
		--opzeggingen met een opzegdatum na vandaag (voor vandaag worden niet meegenomen)
		AND (ml.state = 'paid'
		-- betaald lidmaatschap
			OR ((ml.state = 'invoiced' AND COALESCE(sm.sm_id,0) <> 0)
		-- gefactureerd met domi
					OR (ml.state = 'invoiced' AND COALESCE(i.partner_id,0) <> 0 AND COALESCE(a3.organisation_type_id,0) = 1 )))
);
----------------------------------------
-- 2/ GRATIS LEDEN aantal --------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	2, 'Gratis leden: ', 2 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, '"Leden" en "Gratis leden" moeten samen geteld worden.'
	FROM 	myvar v, res_partner p
	WHERE 	(p.free_member = 't')
		AND p.active = 't'
		AND COALESCE(p.deceased,'f') = 'f' 
);
----------------------------------------
-- 3/ NIEUWE LEDEN aantal --------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	3, 'Nieuwe leden: ', 3 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, '"Nieuwe leden" werden al meegeteld bij "Leden".'
	--=====DETAILS VOOR TEST WAARDEN UIT COMMENTAAR ZETTEN VOOR CONTROLE=====--
	--SELECT p.id, p.membership_state_b HLS, p.membership_start_b Lidmaatschap_startdatum, p.membership_stop_b Lidmaatschap_einddatum, ml.date_from lidmaatschapslijn_start, ml.date_to lidmaatschapslijn_einde, membership_cancel_b
	FROM	myvar v,
		(SELECT MIN(date_from) date_from, MAX(date_to) date_to, partner FROM membership_membership_line GROUP BY partner) ml
		JOIN res_partner p ON p.id = ml.partner
	WHERE p.active = 't'	
		AND COALESCE(p.deceased,'f') = 'f'
		AND ml.date_from BETWEEN v.startdatum AND v.einddatum
		AND ml.date_to >= v.einddatum
		AND COALESCE(membership_cancel_b,'1099-01-01') < v.einddatum
		AND p.membership_state_b <> 'wait_member'
		-- extra controle op startdatum van het lidmaatschap (enkel nodig bij jaarovergang om leden in het nieuwe jaar gecreëerd af te trekken van de "huidige toestand" van het vorige jaar)
		AND p.membership_start < v.cutoffdate
		--AND p.id = 232809
		
);
/*
--SELECT * FROM res_partner WHERE membership_start_b BETWEEN '2015-09-10' AND '2015-10-08' ORDER BY id DESC
SELECT DISTINCT p.membership_nbr, p.membership_cancel_b, ml.* 
FROM myvar v, membership_membership_line ml JOIN res_partner p ON p.id = ml.partner 
WHERE p.membership_start_b BETWEEN '2015-01-01' AND '2015-09-10' AND membership_id IN (2,5,6,7,205,206,207,208) AND COALESCE(membership_cancel_b,'1099-01-01') < v.einddatum
ORDER BY p.membership_nbr DESC

--SELECT * FROM product_product WHERE id = 182
*/
----------------------------------------
-- 7/ LEDEN met MANDAAT aantal ---------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	4, 'Leden met mandaat: ', 9 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, ''
	FROM 	myvar v, res_partner p
		JOIN membership_membership_line ml ON ml.partner = p.id
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--bank/mandaat info
		LEFT OUTER JOIN res_partner_bank pb ON pb.partner_id = p.id
		LEFT OUTER JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id
		--facturen info
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		--aanspreking
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--parnter info
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	WHERE 	--(LOWER(mo.name) LIKE '%fluxys%' AND p.active = 't' AND p.deceased = 'f' AND COALESCE(sm.id,0) > 0)
		--fluxys leden (nog niet in systeem voor 2014 & 2015)
		--OR
		(
		p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		AND ml.date_to BETWEEN v.startdatum and v.einddatum --AND ml.membership_id IN (2,5,6,7,205,206,207,208)
		--enkel lidmaatschapsproduct lijnen met een einddatum in 2015
		AND sm.state = 'valid'
		AND COALESCE(ml.date_cancel,'2099-12-31') > now()::date
		--opzeggingen met een opzegdatum na vandaag (voor vandaag worden niet meegenomen)
		AND (ml.state = 'paid' AND COALESCE(sm.id,0) <> 0
		-- betaald lidmaatschap met domi
			OR ((ml.state = 'invoiced' AND COALESCE(sm.id,0) <> 0)))
		-- gefactureerd met domi
		)
);
--SELECT * FROM sdd_mandate LIMIT 100
----------------------------------------
-- 4/ NIET HERNIEUWDE LEDEN aantal -----
----------------------------------------
-- TEST met betaaldatum: zie "FACTUREN betaald door CREDITNOTA.sql"
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	5, 'Niet hernieuwde leden: ', 4 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, ''
	FROM
		membership_membership_line ml JOIN
		(--SELECT ml1.partner partner/*, il1.**/ FROM membership_membership_line ml1 LEFT OUTER JOIN account_invoice_line il1 ON il1.id = ml1.account_invoice_line
		SELECT ml1.partner partner FROM membership_membership_line ml1
		--WHERE  ml1.date_to BETWEEN '2014-01-01' AND '2014-12-31' AND ml1.membership_id IN (2,5,6,7,205,206,207,208) AND ml1.state = 'paid'
		WHERE  ml1.date_to BETWEEN '2014-01-01' AND '2014-12-31' AND ml1.membership_id IN (2,5,6,7,205,206,207,208) AND ml1.state IN ('paid','canceled')
		) ml2 ON ml.partner = ml2.partner
		JOIN res_partner p ON p.id = ml.partner
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		/*--facturen info
		JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		JOIN account_invoice i ON i.id = il.invoice_id*/
		--bank/mandaat info
		LEFT OUTER JOIN res_partner_bank pb ON pb.partner_id = p.id
		--LEFT OUTER JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id
		LEFT OUTER JOIN (SELECT * FROM sdd_mandate WHERE state = 'valid') sm ON sm.partner_bank_id = pb.id
		--parnter info
		--LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	WHERE p.active = 't' AND COALESCE(p.deceased,'f') = 'f'
		--AND ml.date_to BETWEEN '2015-01-01' AND '2015-08-03' 	
		--AND ml.date_from < '2015-01-01' --extra selectie voor herniewd VOOR de start van 2015
		AND p.membership_end_b BETWEEN '2014-01-01' AND '2014-12-31' 
		--AND COALESCE(ml.state,'_') <> 'paid'
		AND COALESCE(p.membership_state_b,'_') <> 'paid'
		--AND COALESCE(ml.date_cancel,'1099-12-31') <= '2015-07-02'
		--?????opzeggingen uitsluiten????
		AND COALESCE(sm.id,0) = 0
		--geen domiciliering
		--lid via afdeling gewoon meenemen; hiervoor dus geen aparte regel
);
----------------------------------------
-- 10/ ORIOLUS --------------------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	6, 'Abonnement Oriolus: ', 10 volgnummer, 'Abonnementen', COUNT(DISTINCT p.id), now()::date, ''
	FROM myvar v, res_partner p
		JOIN membership_membership_line ml ON ml.partner = p.id
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--bank/mandaat info
		LEFT OUTER JOIN res_partner_bank pb ON pb.partner_id = p.id
		LEFT OUTER JOIN (SELECT * FROM sdd_mandate WHERE state = 'valid') sm ON sm.partner_bank_id = pb.id
		--facturen info
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		--aanspreking
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--parnter info
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	WHERE 	p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		--AND p.address_state_id IN (1,3,4) 
		--"adres verkeerd" niet; moet enkel uitgefilterd worden voor verzendlijst
		AND ml.date_to BETWEEN v.startdatum and v.einddatum AND ml.membership_id IN (4,5,7,8,206,208,209,211)
		--AND ml.date_from < v.cutoffdate --enkel bij jaarovergang
		--enkel lidmaatschaps- en abonnementsproduct lijnen met een einddatum in 2015
		AND COALESCE(ml.date_cancel,'2099-12-31') > now()::date
		--opzeggingen met een opzegdatum na vandaag (voor vandaag worden niet meegenomen)
		AND (ml.state = 'paid'
		-- betaald lidmaatschap
			OR ((ml.state = 'invoiced' AND COALESCE(sm.id,0) <> 0)
		-- gefactureerd met domi
					OR (ml.state = 'invoiced' AND COALESCE(i.partner_id,0) <> 0 AND COALESCE(a3.organisation_type_id,0) = 1 )))
		-- gefactureerd en betaald via afdeling
);
----------------------------------------
-- 11/ FOCUS ----------------------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	7, 'Abonnement Focus: ', 11 volgnummer, 'Abonnementen', COUNT(DISTINCT p.id), now()::date, ''
	FROM myvar v, res_partner p
		JOIN membership_membership_line ml ON ml.partner = p.id
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--bank/mandaat info
		LEFT OUTER JOIN res_partner_bank pb ON pb.partner_id = p.id
		LEFT OUTER JOIN (SELECT * FROM sdd_mandate WHERE state = 'valid') sm ON sm.partner_bank_id = pb.id
		--facturen info
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		--aanspreking
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--parnter info
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	WHERE 	p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		--AND p.address_state_id IN (1,3,4) 
		--"adres verkeerd" niet; moet enkel uitgefilterd worden voor verzendlijst
		AND ml.date_to BETWEEN v.startdatum and v.einddatum AND ml.membership_id IN (3,5,6,8,206,207,209,210)
		--AND ml.date_from < v.cutoffdate --enkel bij jaarovergang
		--enkel lidmaatschaps- en abonnementsproduct lijnen met een einddatum in 2015
		--AND COALESCE(ml.date_cancel,'2099-12-31') > now()::date
		--opzeggingen met een opzegdatum na vandaag (voor vandaag worden niet meegenomen)
		AND (ml.state = 'paid'
		-- betaald lidmaatschap
			OR ((ml.state = 'invoiced' AND COALESCE(sm.id,0) <> 0)
		-- gefactureerd met domi
					OR (ml.state = 'invoiced' AND COALESCE(i.partner_id,0) <> 0 AND COALESCE(a3.organisation_type_id,0) = 1 )))
		-- gefactureerd en betaald via afdeling
);
----------------------------------------
-- 12/ ZOOGDIER -------------------------
----------------------------------------	
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	8, 'Abonnement Zoogdier: ', 12 volgnummer, 'Abonnementen', COUNT(DISTINCT p.id), now()::date, ''
	FROM 	myvar v, res_partner p
		JOIN membership_membership_line ml ON ml.partner = p.id
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--bank/mandaat info
		LEFT OUTER JOIN res_partner_bank pb ON pb.partner_id = p.id
		LEFT OUTER JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id
		--facturen info
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		--aanspreking
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--parnter info
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	WHERE 	p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		--AND p.address_state_id IN (1,3,4) 
		--"adres verkeerd" niet; moet enkel uitgefilterd worden voor verzendlijst 
		AND ml.date_to BETWEEN v.startdatum and v.einddatum AND ml.membership_id IN (204,205,206,207,208,209,210,211)
		--enkel lidmaatschaps- en abonnementsproduct lijnen met zoogdier met een einddatum in 2015
		--AND ml.date_from < v.cutoffdate --enkel bij jaarovergang
		AND COALESCE(ml.date_cancel,'2099-12-31') > now()::date
		--opzeggingen met een opzegdatum na vandaag (voor vandaag worden niet meegenomen)
		AND (ml.state = 'paid'
		-- betaald lidmaatschap
			OR ((ml.state = 'invoiced' AND COALESCE(sm.id,0) <> 0)
		-- gefactureerd met domi
					OR (ml.state = 'invoiced' AND COALESCE(i.partner_id,0) <> 0 AND COALESCE(a3.organisation_type_id,0) = 1 )))
		-- gefactureerd en betaald via afdeling		
);
----------------------------------------
-- 20-23/ Adreswijzigingen -------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
	(--we delen de adreswijziging in in groepen om daarop te tellen
	SELECT 	9, 
		CASE
			WHEN login = 'apiuser' THEN 'Adreswijziging via website: '
			WHEN login = 'admin' THEN 'Adreswijziging via administrator: '
			WHEN login IN ('axel','vera','janvdb') THEN 'Adreswijziging via Ledenadministratie: '
			ELSE 'Adreswijziging via andere: '
		END naam,
		--login naam,
		CASE
			WHEN row_number() over () = 1 THEN 22
			WHEN row_number() over () = 2 THEN 23
			WHEN row_number() over () = 3 THEN 20
			WHEN row_number() over () = 4 THEN 21
		END Volgnummer,
		'Data',
		--row_number() over () Volgnummer,
		COUNT(x.id) Aantal,
		now()::date Datum_gelopen,
		'' Opmerking
	FROM	myvar v, 
		--we tellen lijnen adreshistorie per partner
		--de originele lijn laten we weg omdat dat niet als wijziging moet aanzien worden
		(SELECT ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) AS r,
		p.id p_id, pah.*, u.login
		FROM res_partner p 
		JOIN res_partner_address_history pah ON p.id = pah.partner_id
		JOIN res_users u ON pah.write_uid = u.id
		--WHERE p.id = 133065 
		) x	
	WHERE x.r > 1
		AND x.date_move BETWEEN v.startdatum and v.einddatum	
	GROUP BY naam
);
--------------------------------------------
-- 25/ Deelnemers verrijkingsactie 2015 ----
--------------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT	10, 'Aantal deelnemers verrijkingsactie ', 25 volgnummer, 'Data', COUNT(DISTINCT mailing_list_partner.partner_id), now()::date, ''
	--SELECT DISTINCT COUNT(mailing_list_partner.partner_id) aantal--, SUBSTRING(mailing_list_partner.reference,1,10) datum_deelgenomen 
	FROM mailing_category
		JOIN mailing_mailing on mailing_mailing.category_id = mailing_category.id
		JOIN mailing_list_partner on mailing_list_partner.mailing_id = mailing_mailing.id
	WHERE mailing_category.name = 'Verrijkingsactie' 
		AND mailing_mailing.name = 'V2015_1' 
		AND (SUBSTRING(mailing_list_partner.reference,1,10) <> '' OR NOT(SUBSTRING(mailing_list_partner.reference,1,10) IS NULL))
);
----------------------------------------
-- 30/ foute adressen ------------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	11, 'Leden met een fout adres: ', 30 volgnummer, 'Data', COUNT(DISTINCT p.id), now()::date, 'Geteld op basis van leden, gratis leden en niet hernieuwde leden.'
	FROM 	myvar v, res_partner p
	WHERE 	(membership_state_b IN ('paid','invoiced','wait_member')
		OR p.free_member = 't')
		AND p.address_state_id = 2
);	
----------------------------------------
-- 31/ email adressen ------------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	12, 'Leden met email adres ingevuld: ', 31 volgnummer, 'Data', COUNT(DISTINCT p.id), now()::date, 'Zowel het email adres als het werk email adres worden geteld op basis van leden, gratis leden en niet hernieuwde leden (1x per lid).'
	FROM 	myvar v, res_partner p
	WHERE 	(membership_state_b IN ('paid','invoiced','wait_member')
		OR p.free_member = 't')
		AND (p.email <> '' OR NOT(p.email IS NULL) OR p.email_work <> '' OR NOT(p.email_work IS NULL))
);
----------------------------------------
-- 32/ email telefoonnrs ---------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	13, 'Leden met telefoon nummer ingevuld: ', 32 volgnummer, 'Data', COUNT(DISTINCT p.id), now()::date, 'Zowel het telnr als het werk telnr als het gsm nrs worden geteld op basis van leden, gratis leden en niet hernieuwde leden (1x per lid).'
	FROM 	myvar v, res_partner p
	WHERE 	(membership_state_b IN ('paid','invoiced','wait_member')
		OR p.free_member = 't')
		AND (p.phone <> '' OR NOT(p.phone IS NULL) OR p.phone_work <> '' OR NOT(p.phone_work IS NULL) OR p.mobile <> '' OR NOT(p.mobile IS NULL))
);
-------------------------------------------------------------------
-- 5/ Opzeggingen met onmiddellijke einddatum ---------------------
-------------------------------------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	14, 'Opzeggingen met onmiddellijke einddatum: ', 6 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, 'Op basis van de datum opzegging en de lidmaatschapseinddatum.'
	FROM 	myvar v, res_partner p
		JOIN membership_membership_line ml ON ml.partner = p.id
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--bank/mandaat info
		LEFT OUTER JOIN res_partner_bank pb ON pb.partner_id = p.id
		LEFT OUTER JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id
		--facturen info
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		--aanspreking
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--parnter info
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	WHERE 	--(LOWER(mo.name) LIKE '%fluxys%' AND p.active = 't' AND p.deceased = 'f')
		--fluxys leden (nog niet in systeem voor 2014 & 2015)
		--OR
		(
		p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		AND p.membership_cancel_b BETWEEN v.startdatum and now()::date AND ml.membership_id IN (2,5,6,7,205,206,207,208)
		AND ml.date_to <= now()::date
		

		)
);
-------------------------------------------------------------------
-- 8/ Opzeggingen met einddatum op het einde van dit jaar. --------
-------------------------------------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	15, 'Opzeggingen met einddatum op het einde van dit jaar:', 8 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, 'Op basis van de datum opzegging en de lidmaatschapseinddatum.'
	FROM 	myvar v, res_partner p
		JOIN membership_membership_line ml ON ml.partner = p.id
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--bank/mandaat info
		LEFT OUTER JOIN res_partner_bank pb ON pb.partner_id = p.id
		LEFT OUTER JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id
		--facturen info
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		--aanspreking
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--parnter info
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
	WHERE 	--(LOWER(mo.name) LIKE '%fluxys%' AND p.active = 't' AND p.deceased = 'f')
		--fluxys leden (nog niet in systeem voor 2014 & 2015)
		--OR
		(
		p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		AND p.membership_cancel_b BETWEEN v.startdatum and now()::date AND ml.membership_id IN (2,5,6,7,205,206,207,208)
		AND ml.date_to = v.einddatum
		

		)
);
-------------------------------------------------------------------
-- 6/ Opzeggingen die op inactief werden gezet. -------------------
-------------------------------------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	16, 'Opzeggingen (inactief gezet):', 7 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, 'Een lidmaatschap dat liep in het huidige jaar, maar ondertussen op inactief staat.'
	--SELECT p.id, p.membership_cancel_b, p.active, p.membership_state_b, pi.name, ml.date_from, ml.date_to, ml.state
	FROM 	myvar v, res_partner p
		JOIN membership_membership_line ml ON ml.partner = p.id
		--land, straat, gemeente info
		JOIN res_country c ON p.country_id = c.id
		LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
		LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
		--herkomst lidmaatschap
		LEFT OUTER JOIN res_partner_membership_origin mo ON p.membership_origin_id = mo.id
		--afdeling vs afdeling eigen keuze
		LEFT OUTER JOIN res_partner a ON p.department_id = a.id
		LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
		--bank/mandaat info
		LEFT OUTER JOIN res_partner_bank pb ON pb.partner_id = p.id
		LEFT OUTER JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id
		--facturen info
		LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
		LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
		--aanspreking
		LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
		--parnter info
		LEFT OUTER JOIN res_partner a3 ON i.partner_id = a3.id
		--inactive info
		LEFT OUTER JOIN partner_inactive pi ON p.inactive_id = pi.id
	WHERE 	--(LOWER(mo.name) LIKE '%fluxys%' AND p.active = 't' AND p.deceased = 'f')
		--fluxys leden (nog niet in systeem voor 2014 & 2015)
		--OR
		(
		p.active = 'f'	
		--we tellen voor alle actieve leden
		--AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		--AND p.membership_cancel_b BETWEEN v.startdatum and now()::date --AND ml.membership_id IN (2,5,6,7,205,206,207,208)
		AND ml.date_to BETWEEN v.startdatum AND v.einddatum
		

		)
);
-------------------------------------------------------------------
-- 7/ Berekening vh uitval percentage. ----------------------------
-------------------------------------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(SELECT 17, '% Uitval:', 5 volgnummer, 'Leden', ((SUM(aantal)/v.ledenaantal_vorigjaar)*100)::numeric(5,2), now()::date datum_gelopen, '"% Uitval" is de som van "Niet hernieuwde leden", "Opzeggingen met onmiddelijke einddatum" en "Opzeggingen (inactief gezet)" tov het ledenaantal op het einde van het vorige jaar.'
	FROM myvar v, tempLEDEN_statistiek_manueel WHERE ID IN (5) GROUP BY v.ledenaantal_vorigjaar
);
----------------------------------------
-- LEDEN STATISTIEK --------------------
----------------------------------------
UPDATE tempLEDEN_statistiek_manueel
SET Opmerking = 'Grootste piek ligt hier in de maanden maart en april wanneer de verrijkingsactie via de website liep waarop 23297 leden reageerden.'
WHERE Volgnummer = 21;

SELECT ID, Volgnummer, Naam, Aantal, Datum_gelopen, Opmerking FROM tempLEDEN_statistiek_manueel ORDER BY volgnummer


----------------------------------------
-- TESTEN ------------------------------
----------------------------------------
--SELECT * FROM res_partner LIMIT 100
