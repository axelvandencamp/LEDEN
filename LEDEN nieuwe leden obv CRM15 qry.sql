-- gebaseerd op QRY uit CRM15
-- eerst start lidnummer bepalen
--=================================================================
--SET VARIABLES
DROP TABLE IF EXISTS myvar;
SELECT 
	'2016-07-01'::date AS startdatum, 
	'538178'::text AS lidnummer, --eind 2016
	--'97362'::numeric AS ledenaantal_vorigjaar --eind 2015 
	--,'95163'::numeric AS ledenaantal_vorigjaar --einde 2014
	--,'14-221-295'::text AS uittreksel
	'248580'::numeric AS afdeling 	--248608 - Afdeling Westerlo
	--'2260'::text AS postcode	--2260 - postcode Westerlo
	--'494'::numeric AS herkomst_lidmaatschap  -- 494 = Lampiris
	--'none'::text AS status
	--'248585'::numeric AS wervende_organisatie
	--'261114'::numeric AS test_id
INTO TEMP TABLE myvar;
SELECT * FROM myvar;
--====================================================================
--start lidnummer bepalen op basis van start datum --
-----------------------------------------------------
--SELECT p.id, p.membership_nbr, p.membership_start FROM res_partner p WHERE p.membership_start = '2016-07-01' ORDER BY p.id 
--====================================================================
SELECT p.id, p.membership_start, p.membership_stop, p.membership_end, p.membership_state, p.membership_pay_date, COALESCE(COALESCE(a2.name,a.name),'onbekend') Afdeling, x.type_lid
FROM myvar v, res_partner p
	JOIN (
		
		SELECT id, 'N' as type_lid
		FROM myvar v, res_partner p
		WHERE 	(membership_nbr >  v.lidnummer AND NOT(membership_start IS NULL)) OR (membership_nbr >  v.lidnummer AND free_member)
						AND NOT(membership_state = 'none') AND NOT(membership_state = 'wait_member')
		
		UNION ALL
		
		SELECT id, 'O1' as type_lid
		FROM myvar v, res_partner p
		WHERE membership_nbr < v.lidnummer   
			AND membership_pay_date >=  v.startdatum  
			AND date_part('year',age(membership_stop, membership_start)) <= 0
			AND NOT(membership_start IS NULL)
			AND NOT (id IN (SELECT id FROM _crm_ledenviaafdeling( v.lidnummer, v.startdatum  )))
			AND NOT (id IN (SELECT id FROM _crm_ledenmetdomi( v.lidnummer, v.startdatum  )))
			AND NOT (id IN (SELECT id FROM _crm_ledenviateinnenoverschrijving( v.lidnummer, v.startdatum  )))
		
		UNION ALL
		
		SELECT id, '5' as type_lid FROM myvar v, _crm_leden5j(v.lidnummer,v.startdatum)
		
		UNION ALL

		SELECT id, '1>5' as type_lid FROM myvar v, _crm_leden1tot5j( v.lidnummer, v.startdatum)
		
		UNION ALL
		
		SELECT id, 'V' as type_lid FROM myvar v, _crm_ledennieuwlatergevalideerd( v.lidnummer,  v.startdatum)
		
		UNION ALL
		
		SELECT id, 'O2' as type_lid FROM myvar v, _crm_ledenoudepartnernieuwlid( v.lidnummer ,  v.startdatum)
		
	) x
	ON x.id = p.id
	--afdeling vs afdeling eigen keuze
	LEFT OUTER JOIN res_partner a ON p.department_id = a.id
	LEFT OUTER JOIN res_partner a2 ON p.department_choice_id = a2.id
	
WHERE 
	NOT (p.id IN (SELECT id FROM _crm_ledenmetinactievedubbel()))
	AND COALESCE(p.lidkaart,'false') = 'false'
	AND p.membership_start < now()::date
	AND NOT(p.membership_state = 'wait_member')
	AND NOT(p.membership_state = 'canceled')
	AND COALESCE(a2.id,a.id) = v.afdeling