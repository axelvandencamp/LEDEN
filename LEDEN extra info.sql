-----------------------------------------------------------------------
-- LEDEN extra gegeven: persoons- en lidmaatschapsgegevens
-- - eg.: gebruikt om te koppelen aan IDs fiscale attesten
-----------------------------------------------------------------------
SELECT	DISTINCT--COUNT(p.id) _aantal, now()::date vandaag
	p.id database_id, 
	p.membership_nbr lidnummer, --p.email,
	p.birthday,
	EXTRACT(YEAR from AGE(p.birthday)) AS leeftijd,
	COALESCE(pt.shortcut,CASE WHEN p.gender = 'M' THEN 'Dhr.' WHEN p.gender = 'V' THEN 'Mevr.' END) aanspreking,
	p.gender AS geslacht,
	p.name as partner,
	p.first_name voornaam, p.last_name achternaam,
	COALESCE(p.first_name,'') || ' ' || COALESCE(p.last_name,'') 										as NAW1,
	CASE	WHEN c.id = 21 AND p.crab_used = 'true' THEN COALESCE(ccs.name,'')	ELSE COALESCE(p.street,'')	END || ' ' ||
	CASE	WHEN c.id = 21 AND p.crab_used = 'true' THEN COALESCE(p.street_nbr,'') 	ELSE ''    			END || 
	CASE	WHEN COALESCE(p.street_bus,'_') = '_' OR COALESCE(p.street_bus,'') = ''  THEN '' ELSE ' bus ' || COALESCE(p.street_bus,'') 	END NAW2,
	CASE	WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip			ELSE p.zip			END || ' ' || 
	CASE 	WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.name ELSE p.city 								END NAW3,
	CASE	WHEN c.id = 21 AND p.crab_used = 'true' THEN COALESCE(ccs.name,'')	ELSE COALESCE(p.street,'')				END straat,
	p.street_nbr huisnummer,
	p.street_bus bus,
	CASE	WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip			ELSE p.zip						END postcode,
	CASE 	WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.name ELSE p.city 								END woonplaats,
	--p.postbus_nbr postbus,
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
	CASE
		WHEN p.inactive_id IN (1,8) THEN 'dubbel (via website)' ELSE ''
	END inactieve_dubbel,
	CASE
		WHEN p.inactive_id IN (1,8) THEN p.active_partner_id ELSE 0
	END actieve_partner_id,
	p3.membership_state dubbel_status,
	p2.display_name partner, p2.membership_state partner_status,
	COALESCE(p.email,p.email_work) email,
	sm.sm_bank_bic bic_code,
	sm.sm_acc_number iban,
	COALESCE(p.phone_work,p.phone) telefoonnr,
	p.mobile gsm,
	-- !!! gebruikt van sub query (3x) vertraagt het resultaat van de query                 !!!
	-- !!! indien OGM, bedrag en product niet nodig in resultaat, best in commentaar zetten !!!
	/*(SELECT OGM FROM _crm_leden_factuurinfo(ml.id) ) OGM,
	(SELECT bedrag FROM _crm_leden_factuurinfo(ml.id) ) bedrag,
	(SELECT product FROM _crm_leden_factuurinfo(ml.id) ) product,*/
	--
	p.membership_state status,
	p.membership_start Lidmaatschap_startdatum, 
	p.membership_stop Lidmaatschap_einddatum, 
	p.membership_pay_date Betaaldatum, 
	p.membership_end Recentste_einddatum_lidmaatschap, 
	p.membership_cancel opzegdatum, --opzegdatum
	_crm_opzegdatum_membership(p.id) opzegdatum_LML,
	p.active,
	mo.name herkomst_lidmaatschap,  --membership origin
	p.address_state_id address_state, --waarde 2 is een fout adres
	p.no_magazine no_magazine, --magazine ja/nee
	p.deceased overleden,
	CASE WHEN COALESCE(p.opt_out,'f') = 'f' THEN 'JA' WHEN p.opt_out = 't' THEN 'NEEN' ELSE 'JA' END email_ontvangen,
	CASE WHEN COALESCE(p.opt_out_letter,'f') = 'f' THEN 'JA' WHEN p.opt_out_letter = 't' THEN 'NEEN' ELSE 'JA' END post_ontvangen,
	CASE WHEN COALESCE(sm.sm_id,0) > 0 THEN 1 ELSE 0 END domi,
	CASE WHEN login LIKE('apiuser%') THEN 1 ELSE 0 END via_website,
	CASE WHEN NOT(login LIKE('apiuser%')) THEN 1 ELSE 0 END via_andere,
	--a3.organisation_type_id	--1 indien afdeling
	p.third_payer_id
	--*/
FROM 	res_partner p
	--JOIN membership_membership_line ml ON ml.partner = p.id
	--------------------------------------------
	--SQ1: ophalen van laatste lidmaatschapslijn
	LEFT OUTER JOIN (SELECT partner ml_partner, max(id) ml_id FROM membership_membership_line ml WHERE  /*ml.partner = '55505' AND*/ ml.membership_id IN (2,5,6,7,205,206,207,208) GROUP BY ml.partner) SQ1 ON SQ1.ml_partner = p.id
	------------------------------------- SQ1 --
	-- SQ1 koppelen aan lidmaatschapslijnen om op basis van max(id) de data voor enkel die lijn op te halen
	JOIN membership_membership_line ml ON ml.id = SQ1.ml_id
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
	--LEFT OUTER JOIN res_partner_bank pb ON pb.partner_id = p.id
	--LEFT OUTER JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id
	--door bank aan mandaat te linken en enkel de mandaat info te nemen ontdubbeling veroorzaakt door meerdere bankrekening nummers
	LEFT OUTER JOIN (SELECT pb.id pb_id, pb.partner_id pb_partner_id, sm.id sm_id, sm.state sm_state, pb.bank_bic sm_bank_bic, pb.acc_number sm_acc_number FROM res_partner_bank pb JOIN sdd_mandate sm ON sm.partner_bank_id = pb.id /*WHERE sm.state = 'valid'*/) sm ON pb_partner_id = p.id
	--aangemaakt door 
	JOIN res_users u ON u.id = p.create_uid
	--aanspreking
	LEFT OUTER JOIN res_partner_title pt ON p.title = pt.id
	--gegevens van eventuele partner/dubbel
	LEFT OUTER JOIN res_partner p2 ON p.relation_partner_id = p2.id
	LEFT OUTER JOIN partner_inactive pi ON p.inactive_id = pi.id
	LEFT OUTER JOIN res_partner p3 ON p.active_partner_id = p3.id
	--MAILING LISTs info
	/*INNER JOIN mailing_list_partner mlp ON p.id = mlp.partner_id
	INNER JOIN mailing_list mlst ON mlst.id = mlp.list_id
	INNER JOIN mailing_mailing mm ON mm.id = mlst.mailing_id*/
--WHERE p.membership_end >= '2012-01-01' AND p.active AND COALESCE(p.deceased,'f') = 'f' --AND COALESCE(p.free_member,'f') = 'f' AND p.membership_state = 'paid'
--WHERE p.membership_state IN ('paid','invoiced','free') AND p.membership_start BETWEEN '2016-07-01' AND '2016-08-31'
--WHERE cc.zip = '2800' AND p.street = 'Kardinaal Mercierplein 1'
--WHERE COALESCE(p.department_choice_id,p.department_id) = 248494 AND p.membership_end = '2015-12-31'
--WHERE p.membership_state = 'none' and p.membership_start >= '2017-01-01'
--WHERE p.membership_nbr IN ('256073','523386')
--WHERE p.id IN (20525,77516)
--WHERE p.third_payer_id = 292110
--WHERE mo.id = 494
--WHERE mo.id = 72 AND p.membership_start BETWEEN '2017-11-01' AND '2017-12-31'
--WHERE mm.id = 187
--WHERE p.membership_end >= '2011-01-01' AND p.zip IN ('8500','8501','8501','8510','8510','8510','8510','8511','8520','8530','8531','8540','8550','8551','8552','8553','8554','8560','8560','8560','8570','8570','8570','8570','8572','8573','8580','8581','8581','8582','8583','8587','8587','8587','8770','8790','8791','8792','8793','8860','8870','8870','8870','8930','8930','8930','8800','8840','8830','8880','8890')
WHERE p.email IN ('tineke.thijs@cvn.natuurpunt.be','y.vd.ende@planet.nl')
--p.email LIKE '%21solutions%' OR p.email LIKE '%ab_inbev%' OR p.email LIKE '%abn_amro%' OR p.email LIKE '%accenture%' OR p.email LIKE '%ag%' OR p.email LIKE '%agrofair%' OR p.email LIKE '%ahlers%' OR p.email LIKE '%albe_de_coker%' OR p.email LIKE '%alpro%' OR p.email LIKE '%antiheroes%' OR p.email LIKE '%antwerp_port%' OR p.email LIKE '%apco%' OR p.email LIKE '%ardo%' OR p.email LIKE '%argenta%' OR p.email LIKE '%arjowiggins%' OR p.email LIKE '%art_deco%' OR p.email LIKE '%atlas_copco%' OR p.email LIKE '%axa%' OR p.email LIKE '%baltimore_aircoil_company%' OR p.email LIKE '%beauvent%' OR p.email LIKE '%befimmo%' OR p.email LIKE '%befre%' OR p.email LIKE '%beiersdorf%' OR p.email LIKE '%bel&bo%' OR p.email LIKE '%belfius%' OR p.email LIKE '%beyers%' OR p.email LIKE '%beyers_koffie%' OR p.email LIKE '%bioplanet%' OR p.email LIKE '%bma_ergonomics%' OR p.email LIKE '%bopro%' OR p.email LIKE '%bosch%' OR p.email LIKE '%boydens%' OR p.email LIKE '%bpost%' OR p.email LIKE '%brandsenses%' OR p.email LIKE '%btc%' OR p.email LIKE '%bvba_32_ann_de_meulemeester%' OR p.email LIKE '%c&a%' OR p.email LIKE '%care%' OR p.email LIKE '%cargill%' OR p.email LIKE '%cartamundi%' OR p.email LIKE '%climact%' OR p.email LIKE '%cofely%' OR p.email LIKE '%cofinimmo%' OR p.email LIKE '%colruyt%' OR p.email LIKE '%coop_leuzoise_energies_du_futur%' OR p.email LIKE '%cru%' OR p.email LIKE '%dieteren_vw%' OR p.email LIKE '%dieteren_vw%' OR p.email LIKE '%danone%' OR p.email LIKE '%daoust%' OR p.email LIKE '%de_lijn%' OR p.email LIKE '%delhaize%' OR p.email LIKE '%deloitte%' OR p.email LIKE '%derbigum%' OR p.email LIKE '%ecores%' OR p.email LIKE '%ecover%' OR p.email LIKE '%edf_luminus%' OR p.email LIKE '%efico%' OR p.email LIKE '%electrabel%' OR p.email LIKE '%eml%' OR p.email LIKE '%enenco%' OR p.email LIKE '%esher%' OR p.email LIKE '%etex%' OR p.email LIKE '%exki%' OR p.email LIKE '%factor_4%' OR p.email LIKE '%faitrade_belgium%' OR p.email LIKE '%ferrero%' OR p.email LIKE '%fondation_generations_futures%' OR p.email LIKE '%fost_plus%' OR p.email LIKE '%freshfields%' OR p.email LIKE '%greencaps%' OR p.email LIKE '%iba%' OR p.email LIKE '%iba%' OR p.email LIKE '%ichec%' OR p.email LIKE '%ikea%' OR p.email LIKE '%infrabel%' OR p.email LIKE '%intellisol%' OR p.email LIKE '%iris_group%' OR p.email LIKE '%janssen_pharma%' OR p.email LIKE '%joker%' OR p.email LIKE '%kbc%' OR p.email LIKE '%kiwa%' OR p.email LIKE '%kpmg%' OR p.email LIKE '%kpmg%' OR p.email LIKE '%la_lorraine%' OR p.email LIKE '%lidl%' OR p.email LIKE '%mca_recycling%' OR p.email LIKE '%mccain%' OR p.email LIKE '%mobistar%' OR p.email LIKE '%nagelmackers%' OR p.email LIKE '%nestle%' OR p.email LIKE '%nike%' OR p.email LIKE '%nike%' OR p.email LIKE '%nnof%' OR p.email LIKE '%passiefhuis_platform%' OR p.email LIKE '%pefc%' OR p.email LIKE '%pepsico%' OR p.email LIKE '%petercam%' OR p.email LIKE '%philippe_de_woot%' OR p.email LIKE '%proximus%' OR p.email LIKE '%pwc%' OR p.email LIKE '%quilla%' OR p.email LIKE '%randstad%' OR p.email LIKE '%rescoop%' OR p.email LIKE '%ricoh%' OR p.email LIKE '%rockwool%' OR p.email LIKE '%saint-gobain%' OR p.email LIKE '%siemens%' OR p.email LIKE '%sipef%' OR p.email LIKE '%sodexo%' OR p.email LIKE '%solvay%' OR p.email LIKE '%spadel%' OR p.email LIKE '%stib%' OR p.email LIKE '%strabag%' OR p.email LIKE '%swift%' OR p.email LIKE '%staff.telenet%' OR p.email LIKE '%thalys%' OR p.email LIKE '%triodos%' OR p.email LIKE '%ucb%' OR p.email LIKE '%umicore%' OR p.email LIKE '%unilever%' OR p.email LIKE '%van_marcke%' OR p.email LIKE '%veolia%' OR p.email LIKE '%vigeo%' OR p.email LIKE '%vlerick%' OR
--p.email LIKE '%21solutions%' OR p.email LIKE '%ab-inbev%' OR p.email LIKE '%abn-amro%' OR p.email LIKE '%accenture%' OR p.email LIKE '%ag%' OR p.email LIKE '%agrofair%' OR p.email LIKE '%ahlers%' OR p.email LIKE '%albe-de-coker%' OR p.email LIKE '%alpro%' OR p.email LIKE '%antiheroes%' OR p.email LIKE '%antwerp-port%' OR p.email LIKE '%apco%' OR p.email LIKE '%ardo%' OR p.email LIKE '%argenta%' OR p.email LIKE '%arjowiggins%' OR p.email LIKE '%art-deco%' OR p.email LIKE '%atlas-copco%' OR p.email LIKE '%axa%' OR p.email LIKE '%baltimore-aircoil-company%' OR p.email LIKE '%beauvent%' OR p.email LIKE '%befimmo%' OR p.email LIKE '%befre%' OR p.email LIKE '%beiersdorf%' OR p.email LIKE '%bel&bo%' OR p.email LIKE '%belfius%' OR p.email LIKE '%beyers%' OR p.email LIKE '%beyers-koffie%' OR p.email LIKE '%bioplanet%' OR p.email LIKE '%bma-ergonomics%' OR p.email LIKE '%bopro%' OR p.email LIKE '%bosch%' OR p.email LIKE '%boydens%' OR p.email LIKE '%bpost%' OR p.email LIKE '%brandsenses%' OR p.email LIKE '%btc%' OR p.email LIKE '%bvba-32-ann-de-meulemeester%' OR p.email LIKE '%c&a%' OR p.email LIKE '%care%' OR p.email LIKE '%cargill%' OR p.email LIKE '%cartamundi%' OR p.email LIKE '%climact%' OR p.email LIKE '%cofely%' OR p.email LIKE '%cofinimmo%' OR p.email LIKE '%colruyt%' OR p.email LIKE '%coop-leuzoise-energies-du-futur%' OR p.email LIKE '%cru%' OR p.email LIKE '%dieteren-vw%' OR p.email LIKE '%dieteren-vw%' OR p.email LIKE '%danone%' OR p.email LIKE '%daoust%' OR p.email LIKE '%de-lijn%' OR p.email LIKE '%delhaize%' OR p.email LIKE '%deloitte%' OR p.email LIKE '%derbigum%' OR p.email LIKE '%ecores%' OR p.email LIKE '%ecover%' OR p.email LIKE '%edf-luminus%' OR p.email LIKE '%efico%' OR p.email LIKE '%electrabel%' OR p.email LIKE '%eml%' OR p.email LIKE '%enenco%' OR p.email LIKE '%esher%' OR p.email LIKE '%etex%' OR p.email LIKE '%exki%' OR p.email LIKE '%factor-4%' OR p.email LIKE '%faitrade-belgium%' OR p.email LIKE '%ferrero%' OR p.email LIKE '%fondation-generations-futures%' OR p.email LIKE '%fost-plus%' OR p.email LIKE '%freshfields%' OR p.email LIKE '%greencaps%' OR p.email LIKE '%iba%' OR p.email LIKE '%iba%' OR p.email LIKE '%ichec%' OR p.email LIKE '%ikea%' OR p.email LIKE '%infrabel%' OR p.email LIKE '%intellisol%' OR p.email LIKE '%iris-group%' OR p.email LIKE '%janssen-pharma%' OR p.email LIKE '%joker%' OR p.email LIKE '%kbc%' OR p.email LIKE '%kiwa%' OR p.email LIKE '%kpmg%' OR p.email LIKE '%kpmg%' OR p.email LIKE '%la-lorraine%' OR p.email LIKE '%lidl%' OR p.email LIKE '%mca-recycling%' OR p.email LIKE '%mccain%' OR p.email LIKE '%mobistar%' OR p.email LIKE '%nagelmackers%' OR p.email LIKE '%nestle%' OR p.email LIKE '%nike%' OR p.email LIKE '%nike%' OR p.email LIKE '%nnof%' OR p.email LIKE '%passiefhuis-platform%' OR p.email LIKE '%pefc%' OR p.email LIKE '%pepsico%' OR p.email LIKE '%petercam%' OR p.email LIKE '%philippe-de-woot%' OR p.email LIKE '%proximus%' OR p.email LIKE '%pwc%' OR p.email LIKE '%quilla%' OR p.email LIKE '%randstad%' OR p.email LIKE '%rescoop%' OR p.email LIKE '%ricoh%' OR p.email LIKE '%rockwool%' OR p.email LIKE '%saint-gobain%' OR p.email LIKE '%siemens%' OR p.email LIKE '%sipef%' OR p.email LIKE '%sodexo%' OR p.email LIKE '%solvay%' OR p.email LIKE '%spadel%' OR p.email LIKE '%stib%' OR p.email LIKE '%strabag%' OR p.email LIKE '%swift%' OR p.email LIKE '%staff.telenet%' OR p.email LIKE '%thalys%' OR p.email LIKE '%triodos%' OR p.email LIKE '%ucb%' OR p.email LIKE '%umicore%' OR p.email LIKE '%unilever%' OR p.email LIKE '%van-marcke%' OR p.email LIKE '%veolia%' OR p.email LIKE '%vigeo%' OR p.email LIKE '%vlerick%'
--WHERE mm.name = 'Niet Lid via website okt-nov '
--WHERE p.membership_end BETWEEN '2013-01-01' AND '2015-12-31' AND _crm_opzegdatum_membership(p.id) BETWEEN '2017-11-01' AND '2017-12-31' -- lijst "late hernieuwers 1>5j" met status "cancelled"; foutief stopgezet;

--LIMIT 100

--SELECT p.id, p.membership_nbr, p.third_payer_id FROM res_partner p WHERE p.third_payer_id = 292110

--542102

--SELECT partner sm_partner, max(id) sm_id FROM membership_membership_line ml WHERE  ml.partner = '55505' AND ml.membership_id IN (2,5,6,7,205,206,207,208) GROUP BY ml.partner

--SELECT * FROM mailing_list_partner mlp LIMIT 100
--SELECT * FROM mailing_list mlst LIMIT 100
--SELECT * FROM mailing_mailing mm WHERE LOWER(mm.name) LIKE '012018%' LIMIT 100
