SELECT	DISTINCT--COUNT(p.id) _aantal, now()::date vandaag
	p.id database_id, 
	p.membership_nbr lidnummer, 
	COALESCE(p.first_name,'') as voornaam,
	COALESCE(p.last_name,'') as achternaam,
	ot.name organisatie_type,
	p.email,
	p.membership_state huidige_lidmaatschap_status,
	COALESCE(p.membership_start,p.create_date::date) aanmaak_datum,
	ml.date_from lml_date_from,
	p.membership_start Lidmaatschap_startdatum, 
	p.membership_stop Lidmaatschap_einddatum,  
	p.membership_pay_date betaaldatum,
	p.membership_renewal_date hernieuwingsdatum,
	p.membership_end recentste_einddatum_lidmaatschap,
	p.membership_cancel membership_cancel,
	_crm_opzegdatum_membership(p.id) opzegdatum_LML,
	p.active
FROM 	_av_myvar v, res_partner p
	--Voor de ontdubbeling veroorzaakt door meedere lidmaatschapslijnen
	LEFT OUTER JOIN (SELECT * FROM _av_myvar v, membership_membership_line ml JOIN product_product pp ON pp.id = ml.membership_id WHERE  ml.date_to BETWEEN v.startdatum and v.einddatum AND pp.membership_product) ml ON ml.partner = p.id
	JOIN res_organisation_type ot ON ot.id = p.organisation_type_id
--=============================================================================
WHERE 	p.active = 't'	
	--we tellen voor alle actieve leden
	AND COALESCE(p.deceased,'f') = 'f' 
	--overledenen niet
	--AND COALESCE(p.free_member,'f') = 'f'
	AND p.membership_state IN ('paid','invoiced','free') 
	AND p.organisation_type_id IN (23,16,15) -- werking natuur.huis, werking bezoekerscentrum, gebouw)
ORDER BY
	ot.name
