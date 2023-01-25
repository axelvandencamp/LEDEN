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
	 ,afdeling integer[], postcode TEXT, herkomst_lidmaatschap NUMERIC, wervende_organisatie NUMERIC, test_id NUMERIC
	 );

INSERT INTO _AV_myvar VALUES('2022-01-01',	--startdatum
				'2023-12-31',	--einddatum
				'{248524,248549}', --afdeling 	
				'2260', --postcode
				494,  	--numeric 
				248585,	--wervende_organisatie
				'16382'	--numeric
				);
SELECT * FROM _AV_myvar;
--====================================================================
--====================================================================
SELECT	
	sq1.partner_id, sq1.lidnummer, sq1.geslacht, sq1.voornaam, sq1.achternaam, sq1.building huisnaam, sq1.straat, sq1.huisnummer, sq1.bus, sq1.postcode, sq1.woonplaats, sq1.land, 
	sq1.email, sq1.telefoonnr, sq1.gsm, sq1.afdeling, sq1.birthday, sq1.leeftijd, 
	COALESCE(p.membership_start,p.create_date::date) aanmaak_datum,
	EXTRACT(YEAR from AGE(p.membership_start)) aantal_jaren_lid,
	sq1.adres_status adres_verkeerd, sq1.nooit_contact, sq1.wenst_geen_post_van_np, sq1.wenst_geen_email_van_np, 
	d.jaareerstegift don_jaareerstegift, d.jaarlaatstegift don_jaarlaatstegift, d.jarendonateur don_jarendonateur, d.aantalgiften don_aantalgiften, d.totaalgiften don_totaalgiften, d.grootstegift don_grootstegift, d.avggiftenperjaar don_avggiftenperjaar, d.avgbedragperjaar don_avgbedragperjaar, 
	COALESCE(p2.erflater,0) erflater, COALESCE(p2.commerciële_partner) commerciële_partner, COALESCE(p2.bos_partner) bos_partner, COALESCE(p2.major_donor) major_donor, COALESCE(p2.schenker_grond) schenker_grond, p2.vrijwilliger, p2.bestuurder, p2.conservator, p2.aankoper
FROM 	_av_myvar v, res_partner p
	JOIN marketing._crm_partnerinfo() sq1 ON sq1.partner_id = p.id
	JOIN marketing._m_dwh_partners p2 ON p2.partner_id = p.id
	LEFT OUTER JOIN marketing._m_dwh_donateursprofiel d ON d.partner_id = p.id
	JOIN res_country c ON p.country_id = c.id
	LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
	LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
	--afdeling vs afdeling eigen keuze
	LEFT OUTER JOIN res_partner a ON p.department_id = a.id
	LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
--=============================================================================
WHERE 	p.active = 't'	
	--we tellen voor alle actieve leden
	AND COALESCE(p.deceased,'f') = 'f' 
	--overledenen niet
	AND p.membership_state IN ('paid','invoiced','free') 
	--afdeling
	AND COALESCE(COALESCE(a2.id,a.id),0) = ANY (v.afdeling)
	