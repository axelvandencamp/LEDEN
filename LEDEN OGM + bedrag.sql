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

INSERT INTO _AV_myvar VALUES('2025-01-01',	--startdatum
				'2026-12-31',	--einddatum
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
	COALESCE(p.first_name,'') as voornaam,
	COALESCE(p.last_name,'') as achternaam,
	p.membership_state huidige_lidmaatschap_status,
	i.reference OGM,
	i.amount_total bedrag,
	'https://pay.pom.be/'||pom.pom_paylink_short pom_paylink	
FROM 	_av_myvar v, res_partner p
	--Voor de ontdubbeling veroorzaakt door meedere lidmaatschapslijnen
	JOIN (SELECT partner partner_id, max(ml.id) ml_id FROM _av_myvar v, membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id WHERE  ml.date_to BETWEEN v.startdatum and v.einddatum AND pp.membership_product GROUP BY partner) sq1 ON sq1.partner_id = p.id
	JOIN membership_membership_line ml ON ml.id = sq1.ml_id
	--bank/mandaat info
	--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
	LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id WHERE sm.state = 'valid') sm ON pb_partner_id = p.id
	--facturen info
	LEFT OUTER JOIN account_invoice_line il ON il.id = ml.account_invoice_line
	LEFT OUTER JOIN account_invoice i ON i.id = il.invoice_id
	--pom paylink
	LEFT OUTER JOIN pom_paylink pom ON pom.id =i.pom_paylink_id

--=============================================================================
WHERE 	p.active = 't'	
	AND (p.membership_state IN ('paid','invoiced') OR COALESCE(p.free_member,'f') = 't')