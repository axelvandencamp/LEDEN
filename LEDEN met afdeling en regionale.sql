--SELECT r.id, r.name, * 
SELECT r.id, r.name, COUNT(r.id) aantal
FROM marketing._CRM_partnerinfo() sq1
	JOIN (
--
	SELECT p.id partner_id, a.id afdeling_id, ot1.id, r.id regionaal_id, ot2.id
	FROM res_partner p
		LEFT OUTER JOIN res_partner a ON a.id = COALESCE(p.department_choice_id,p.department_id)
		LEFT OUTER JOIN res_organisation_type ot1 ON ot1.id = a.organisation_type_id
		LEFT OUTER JOIN res_partner r ON a.partner_up_id = r.id
		LEFT OUTER JOIN res_organisation_type ot2 ON ot2.id = r.organisation_type_id
	WHERE p.membership_state IN ('paid','invoiced','free')
--
	) sq2 ON sq2.partner_id = sq1.partner_id
	JOIN res_partner r ON r.id = sq2.regionaal_id
--WHERE r.id = 17230
GROUP BY r.id, r.name
	




