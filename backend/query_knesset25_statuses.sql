-- Get all distinct KNS_Status values that appear in KNS_Bill for Knesset 25
SELECT DISTINCT 
    s.StatusID,
    s.Desc AS StatusDescription,
    s.TypeID,
    s.TypeDesc AS StatusType,
    COUNT(b.BillID) AS BillCount
FROM 
    "_KNS_Bill" b
    INNER JOIN "_KNS_Status" s ON b.StatusID = s.StatusID
WHERE 
    b.KnessetNum = 25
GROUP BY 
    s.StatusID, s.Desc, s.TypeID, s.TypeDesc
ORDER BY 
    s.TypeID, s.Desc;
