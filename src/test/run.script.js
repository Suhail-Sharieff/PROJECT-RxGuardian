import fetch from "node-fetch";

const URL = process.argv[2];
const COOKIES = process.argv[3];

const data = [
  {"name":"GlobeMed Pharma","address":"Visakhapatnam, AP","phone":"9978901234","email":"globemed@pharma.com","license":"LIC-GM021","password":"globeMed@2025"},
{"name":"NeoCure Labs","address":"Ranchi, JH","phone":"9989012345","email":"neocure@labs.com","license":"LIC-NC022","password":"neoCure#456"},
{"name":"AstraWell Biotech","address":"Kanpur, UP","phone":"9990123456","email":"astrawell@biotech.com","license":"LIC-AW023","password":"astraWell@lab"},
{"name":"PureLife Remedies","address":"Rajkot, GJ","phone":"9971234567","email":"purelife@remedies.com","license":"LIC-PL024","password":"pureLife@safe"},
{"name":"MediCore Pvt Ltd","address":"Coimbatore, TN","phone":"9962345678","email":"medicore@pvt.com","license":"LIC-MC025","password":"mediCore#2024"},
{"name":"Innova Meds","address":"Varanasi, UP","phone":"9953456789","email":"innova@meds.com","license":"LIC-IM026","password":"innovaMeds@123"},
{"name":"WellCare Therapeutics","address":"Amritsar, PB","phone":"9944567890","email":"wellcare@thera.com","license":"LIC-WT027","password":"wellCare@2025"},
{"name":"PharmaLink Ltd","address":"Dehradun, UK","phone":"9935678901","email":"pharmalink@ltd.com","license":"LIC-PL028","password":"pharmaLink@secure"},
{"name":"TruHealth Biopharma","address":"Shillong, ML","phone":"9926789012","email":"truhealth@bio.com","license":"LIC-TH029","password":"truHealth#med"},
{"name":"NextGen Remedies","address":"Jodhpur, RJ","phone":"9917890123","email":"nextgen@remedies.com","license":"LIC-NR030","password":"nextGen@2025"},

];

for (const m of data) {
  console.log("Sending:", m);
  const res = await fetch(URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Cookie": COOKIES
    },
    body: JSON.stringify(m),
  });
  console.log(await res.text());
  console.log("---");
}

//ex:node ./src/test/run.script.js "http://localhost:8080/manufacturer/addManufacturer" "accessToken=xxx; refreshToken=yyy"
