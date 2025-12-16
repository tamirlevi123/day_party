import sqlite3

conn = sqlite3.connect('data/knesset_data.db')
cursor = conn.cursor()

query = """
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
    s.TypeID, s.Desc
"""

cursor.execute(query)
rows = cursor.fetchall()

print("StatusID | StatusDescription | TypeID | StatusType | BillCount")
print("-" * 90)
for r in rows:
    print(f"{r[0]:8} | {str(r[1]):20} | {r[2]:6} | {str(r[3]):15} | {r[4]:9}")

print(f"\nTotal distinct statuses: {len(rows)}")
conn.close()
