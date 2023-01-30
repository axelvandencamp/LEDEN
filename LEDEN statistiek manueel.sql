--=================================================================
--SET VARIABLES
DROP TABLE IF EXISTS _AV_myvar;
CREATE TEMP TABLE _AV_myvar 
	(startdatum DATE, einddatum DATE, ledenaantal_vorigjaar NUMERIC);

INSERT INTO _AV_myvar VALUES('2023-01-01',	--startdatum
				'2024-12-31',				--einddatum
				131703);					--ledenaantal_vorigjaar
				
SELECT * FROM _AV_myvar;
--====================================================================
-----------------------------------------
-- TELLING LEDEN VIA WEBSITE TOEVOEGEN --
-----------------------------------------
-- SELECT COUNT(id) FROM res_partner WHERE membership_state IN ('paid','free','invoiced') AND active AND COALESCE(deceased,'f') = 'f' AND membership_start < '2021-01-01'
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
	FROM 	_AV_myvar v, res_partner p
	WHERE 	p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		AND COALESCE(p.free_member,'f') = 'f'
		--gratis leden niet
		AND p.membership_state IN ('paid','invoiced')
		--AND p.membership_start < '2021-01-01'
);
----------------------------------------
-- 2/ GRATIS LEDEN aantal --------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	2, 'Gratis leden: ', 2 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, '"Leden" en "Gratis leden" moeten samen geteld worden.'
	FROM 	_AV_myvar v, res_partner p
	WHERE 	(p.free_member = 't')
		AND p.active = 't'
		AND COALESCE(p.deceased,'f') = 'f' 
);
----------------------------------------
-- 3/ NIEUWE LEDEN aantal --------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	--SELECT 	3, 'Nieuwe leden: ', 3 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, '"Nieuwe leden" werden al meegeteld bij "Leden".'
	--=====DETAILS VOOR TEST WAARDEN UIT COMMENTAAR ZETTEN VOOR CONTROLE=====--
	--SELECT p.id, p.membership_state_b HLS, p.membership_start_b Lidmaatschap_startdatum, p.membership_stop_b Lidmaatschap_einddatum, ml.date_from lidmaatschapslijn_start, ml.date_to lidmaatschapslijn_einde, membership_cancel_b
	SELECT 3, 'Niewe leden:', 3 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, '"Nieuwe leden" werden al meegeteld bij "Leden".'
	FROM _AV_myvar v, res_partner p
	WHERE p.membership_state IN ('paid','invoiced','free')
		AND p.membership_start >= v.startdatum
		--AND p.membership_start < '2023-01-01' -- jaarovergang
		
);
----------------------------------------
-- 3/ NIEUWE LEDEN aantal via website --
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	--SELECT 	3, 'Nieuwe leden: ', 3 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, '"Nieuwe leden" werden al meegeteld bij "Leden".'
	--=====DETAILS VOOR TEST WAARDEN UIT COMMENTAAR ZETTEN VOOR CONTROLE=====--
	--SELECT p.id, p.membership_state_b HLS, p.membership_start_b Lidmaatschap_startdatum, p.membership_stop_b Lidmaatschap_einddatum, ml.date_from lidmaatschapslijn_start, ml.date_to lidmaatschapslijn_einde, membership_cancel_b
	SELECT 3, 'Niewe leden via website:', 10 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, ''
	FROM _AV_myvar v, res_partner p
		JOIN res_users u ON p.create_uid = u.id
	WHERE p.membership_state IN ('paid','invoiced','free')
		AND p.membership_start >= v.startdatum
		AND u.login = 'apiuser' 
		
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
	FROM 	_AV_myvar v, res_partner p
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
(	
	SELECT 5, 'Niet hernieuwde leden: ', 4 volgnummer, 'Leden', COUNT(DISTINCT p.id), now()::date, ''
	FROM _AV_myvar v, res_partner p
	WHERE p.membership_end = (v.startdatum + INTERVAL 'day -1')::date
		AND NOT(p.membership_state IN ('canceled','invoiced'))
		--AND p.membership_start < '2023-01-01' -- jaarovergang
);
----------------------------------------
-- 5/ NIET HERNIEUWDE LEDEN procentueel -----
----------------------------------------
-- TEST met betaaldatum: zie "FACTUREN betaald door CREDITNOTA.sql"
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(
	SELECT 17, '% Uitval: ', 5 volgnummer, 'Leden', ((aantal/v.ledenaantal_vorigjaar)*100)::decimal(5,2), now()::date, 'berekend op ledentotaal van vorig jaar: '||v.ledenaantal_vorigjaar::text
	FROM _AV_myvar v, tempLEDEN_statistiek_manueel statm
	WHERE statm.id = 5
);
----------------------------------------
-- 10/ ORIOLUS -------------------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	6, 'Abonnement Oriolus: ', 20 volgnummer, 'Abonnementen', COUNT(DISTINCT p.id), now()::date, ''
	--SELECT DISTINCT p.id
	FROM _AV_myvar v, res_partner p
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
	-- voor jaarcijfers in januari gelopen voor het vorige jaar
	-- enkel 'paid' abonnementslijnen
	-- einddatum 1 jaar verder zetten (voor 2017 van 01/01/2017 tem 31/12/2018)
	-- startdatum mag niet groter dan einde vh jaar zijn (voor 2017 dus 31/12/2017)
	-- best nog controleren op dubbels
	WHERE 	p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		--AND p.address_state_id IN (1,3,4) 
		--"adres verkeerd" niet; moet enkel uitgefilterd worden voor verzendlijst
		AND ml.date_to BETWEEN v.startdatum and v.einddatum AND ml.membership_id IN (4,5,7,8,206,208,209,211) --AND ml.date_from < '2017-12-31'
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
(	SELECT 	7, 'Abonnement Focus: ', 21 volgnummer, 'Abonnementen', COUNT(DISTINCT p.id), now()::date, ''
	--SELECT DISTINCT p.id
	FROM _AV_myvar v, res_partner p
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
	-- voor jaarcijfers in januari gelopen voor het vorige jaar
	-- enkel 'paid' abonnementslijnen
	-- einddatum 1 jaar verder zetten (voor 2017 van 01/01/2017 tem 31/12/2018)
	-- startdatum mag niet groter dan einde vh jaar zijn (voor 2017 dus 31/12/2017)
	-- best nog controleren op dubbels
	WHERE 	p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		--AND p.address_state_id IN (1,3,4) 
		--"adres verkeerd" niet; moet enkel uitgefilterd worden voor verzendlijst
		AND ml.date_to BETWEEN v.startdatum and v.einddatum AND ml.membership_id IN (3,5,6,8,206,207,209,210) --AND ml.date_from < '2017-12-31'
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
(	SELECT 	8, 'Abonnement Zoogdier: ', 22 volgnummer, 'Abonnementen', COUNT(DISTINCT p.id), now()::date, ''
	--SELECT DISTINCT p.id
	FROM 	_AV_myvar v, res_partner p
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
	-- voor jaarcijfers in januari gelopen voor het vorige jaar
	-- enkel 'paid' abonnementslijnen
	-- einddatum 1 jaar verder zetten (voor 2017 van 01/01/2017 tem 31/12/2018)
	-- startdatum mag niet groter dan einde vh jaar zijn (voor 2017 dus 31/12/2017)
	-- best nog controleren op dubbels
	WHERE 	p.active = 't'	
		--we tellen voor alle actieve leden
		AND COALESCE(p.deceased,'f') = 'f' 
		--overledenen niet
		--AND p.address_state_id IN (1,3,4) 
		--"adres verkeerd" niet; moet enkel uitgefilterd worden voor verzendlijst 
		AND ml.date_to BETWEEN v.startdatum and v.einddatum AND ml.membership_id IN (204,205,206,207,208,209,210,211) --AND ml.date_from < '2017-12-31'
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
			WHEN login IN ('axel.vandencamp','vera.baetens','kristien.vercauteren','griet.vandendriessche') THEN 'Adreswijziging via Ledenadministratie: '
			ELSE 'Adreswijziging via andere: '
		END naam,
		--login,
		--row_number() over (),
		CASE
			WHEN row_number() over () = 1 THEN 30
			WHEN row_number() over () = 2 THEN 31
			WHEN row_number() over () = 3 THEN 32
			WHEN row_number() over () = 4 THEN 33
		END Volgnummer,
		'Data',
		--row_number() over () Volgnummer,
		COUNT(x.id) Aantal,
		now()::date Datum_gelopen,
		'' Opmerking
	FROM	_AV_myvar v, 
		--we tellen lijnen adreshistorie per partner
		--de originele lijn laten we weg omdat dat niet als wijziging moet aanzien worden
		(SELECT ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY pah.date_move ASC) AS r,
		p.id p_id, pah.*, 
		u.login
		FROM res_partner p 
		JOIN res_partner_address_history pah ON p.id = pah.partner_id
		JOIN res_users u ON pah.write_uid = u.id
		--WHERE p.id = 133065 
		) x	
	WHERE x.r > 1
		AND x.date_move BETWEEN v.startdatum and v.einddatum	
	GROUP BY naam--, login
);
--------------------------------------------
-- 25/ Deelnemers verrijkingsactie 2015 ----
--------------------------------------------
/*INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT	10, 'Aantal deelnemers verrijkingsactie ', 25 volgnummer, 'Data', COUNT(DISTINCT mailing_list_partner.partner_id), now()::date, ''
	--SELECT DISTINCT COUNT(mailing_list_partner.partner_id) aantal--, SUBSTRING(mailing_list_partner.reference,1,10) datum_deelgenomen 
	FROM mailing_category
		JOIN mailing_mailing on mailing_mailing.category_id = mailing_category.id
		JOIN mailing_list_partner on mailing_list_partner.mailing_id = mailing_mailing.id
	WHERE mailing_category.name = 'Verrijkingsactie' 
		AND mailing_mailing.name = 'V2015_1' 
		AND (SUBSTRING(mailing_list_partner.reference,1,10) <> '' OR NOT(SUBSTRING(mailing_list_partner.reference,1,10) IS NULL))
);
*/
----------------------------------------
-- 30/ foute adressen ------------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	11, 'Leden met een fout adres: ', 34 volgnummer, 'Data', COUNT(DISTINCT p.id), now()::date, 'Geteld op basis van leden, gratis leden en niet hernieuwde leden.'
	FROM 	_AV_myvar v, res_partner p
	WHERE 	(membership_state_b IN ('paid','invoiced','wait_member')
		OR p.free_member = 't')
 		--AND p.membership_start < '2023-01-01' -- jaarovergang
		AND p.address_state_id = 2
);	
----------------------------------------
-- 31/ email adressen ------------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	12, 'Leden met email adres ingevuld: ', 35 volgnummer, 'Data', COUNT(DISTINCT p.id), now()::date, 'Zowel het email adres als het werk email adres worden geteld op basis van leden, gratis leden en niet hernieuwde leden (1x per lid).'
	FROM 	_AV_myvar v, res_partner p
	WHERE --alle actieve leden
		p.active = 't'	
		--overledenen niet
		AND COALESCE(p.deceased,'f') = 'f'
		--betaald, domi of gratis
		AND (p.membership_state IN ('paid','invoiced') OR p.free_member)
		--AND p.membership_start < '2023-01-01' -- jaarovergang
		AND (NOT(COALESCE(p.email_work,p.email) IS NULL) OR COALESCE(p.email_work,p.email) <> '') --(p.email <> '' OR NOT(p.email IS NULL) OR p.email_work <> '' OR NOT(p.email_work IS NULL))
);

----------------------------------------
-- 32/ email telefoonnrs ---------------
----------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	13, 'Leden met telefoon nummer ingevuld: ', 36 volgnummer, 'Data', COUNT(DISTINCT p.id), now()::date, 'Zowel het telnr als het werk telnr als het gsm nrs worden geteld op basis van leden, gratis leden en niet hernieuwde leden (1x per lid).'
	FROM 	_AV_myvar v, res_partner p
	WHERE 	(membership_state_b IN ('paid','invoiced','wait_member')
		OR p.free_member = 't')
		AND (p.phone <> '' OR NOT(p.phone IS NULL) OR p.phone_work <> '' OR NOT(p.phone_work IS NULL) OR p.mobile <> '' OR NOT(p.mobile IS NULL))
);
-------------------------------------------------------------------
-- 5/ Opzeggingen met onmiddellijke einddatum ---------------------
-------------------------------------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	14, 'Opzeggingen met onmiddellijke einddatum: ', 6 volgnummer, 'Leden', COUNT(DISTINCT sq1.id), now()::date, 'Op basis van de datum opzegging en de lidmaatschapseinddatum.'
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
);
-------------------------------------------------------------------
-- 8/ Opzeggingen met einddatum op het einde van dit jaar. --------
-------------------------------------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	15, 'Opzeggingen met einddatum op het einde van dit jaar:', 8 volgnummer, 'Leden', COUNT(DISTINCT sq1.id), now()::date, 'Op basis van de datum opzegging en de lidmaatschapseinddatum.'
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
);
-------------------------------------------------------------------
-- 6/ Opzeggingen die op inactief werden gezet. -------------------
-------------------------------------------------------------------
INSERT INTO tempLEDEN_statistiek_manueel
(	SELECT 	16, 'Opzeggingen (inactief gezet):', 7 volgnummer, 'Leden', COUNT(DISTINCT sq1.id), now()::date, 'Een lidmaatschap dat liep in het huidige jaar, maar ondertussen op inactief staat.'
	FROM (
		SELECT p.id, p.name, p.membership_state, p.membership_end, ml.date_cancel, ml.state
		FROM _AV_myvar v, 
			res_partner p
			JOIN membership_membership_line ml ON p.id = ml.partner
		WHERE ml.date_cancel BETWEEN v.startdatum AND v.einddatum
			--AND p.membership_start < '2023-01-01' -- jaarovergang
			AND p.active = 'f'	
		) SQ1
);

----------------------------------------
-- LEDEN STATISTIEK --------------------
----------------------------------------
SELECT * FROM tempLEDEN_statistiek_manueel ORDER BY volgnummer


----------------------------------------
-- TESTEN ------------------------------
----------------------------------------
--SELECT * FROM res_partner LIMIT 100