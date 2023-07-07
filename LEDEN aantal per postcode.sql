SELECT COUNT(p.id) aantal,
	CASE
		WHEN c.id = 21 AND p.crab_used = 'true' THEN cc.zip
		ELSE p.zip
	END postcode,
	CASE 
		WHEN c.id = 21 THEN cc.name ELSE p.city 
	END woonplaats
FROM res_partner p
	--land, straat, gemeente info
	JOIN res_country c ON p.country_id = c.id
	LEFT OUTER JOIN res_country_city_street ccs ON p.street_id = ccs.id
	LEFT OUTER JOIN res_country_city cc ON p.zip_id = cc.id
WHERE p.membership_state IN ('paid','invoiced','free')
	AND p.zip IN ('3970','3971')
GROUP BY c.id, cc.zip, cc.name, p.zip, p.city, p.crab_used