import { db } from "../Utils/sql_connection.utils.js";
import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { getShopImWorkingIn } from "./shop.controller.js";

import { buildPaginatedFilters } from "../Utils/paginated_query_builder.js";

const initSale = asyncHandler(async (req, res) => {
  const { pharmacist_id } = req.pharmacist;
  const shop_id = await getShopImWorkingIn(req, res);

  const { items, discount = 0,customer_id } = req.body;

  if (!Array.isArray(items) || items.length === 0) {
    throw new ApiError(400, "Provide items array with { drug_id, quantity }");
  }

  if(!customer_id) throw new ApiError(400,"Please provide customer id")


  for (const it of items) {
    if (
      !it ||
      typeof it.drug_id !== "number" ||
      typeof it.quantity !== "number" ||
      it.quantity <= 0
    ) {
      throw new ApiError(
        400,
        "Each item must include numeric drug_id and positive quantity"
      );
    }
  }

  try {

    const [saleResult] = await db.execute(
      "INSERT INTO sale (shop_id, pharmacist_id, discount,customer_id) VALUES (?, ?, ?,?)",
      [shop_id, pharmacist_id, discount,customer_id]
    );
    const sale_id = saleResult.insertId;
    if (!sale_id) throw new ApiError(500, "Failed to create sale");

    const placeholders = items.map(() => "(?,?,?)").join(",");
    const values = items.flatMap((it) => [sale_id, it.drug_id, it.quantity]);
    const insertQuery = `INSERT INTO sale_item (sale_id, drug_id, quantity) VALUES ${placeholders}`;

    console.log(`place holder to insert are: ${placeholders}`);

    const [itemsResult] = await db.execute(insertQuery, values);

    for (const it of items) {
      const [upd] = await db.execute(
        "UPDATE quantity SET quantity = quantity - ? WHERE drug_id = ? AND shop_id = ? AND quantity >= ?",
        [it.quantity, it.drug_id, shop_id, it.quantity]
      );
      if (upd.affectedRows === 0) {
        throw new ApiError(
          400,
          `Insufficient stock in shop ${shop_id} for drug_id ${it.drug_id}`
        );
      }
    }


    return res.status(200).json(
      new ApiResponse(
        200,
        { sale_id, itemsInserted: itemsResult.affectedRows },
        "Sale created successfully"
      )
    );
  } catch (err) {
    if (err instanceof ApiError) throw err;
    throw new ApiError(500, err.message || "Database error during sale creation");
  }
});

const getOverallSales=asyncHandler(
  async(req,res)=>{

      try{
      const shop_id=await getShopImWorkingIn(req,res);
      const { limit, offset, whereClause, params } = buildPaginatedFilters({
            req,
            baseParams: [shop_id],
            allowedFilters: [
              { key: "searchByName", column: "p.name", type: "string" },
              { key: "searchBySaleId", column: "sa.sale_id", type: "number" },
              { key: "searchByPharmacistId", column: "p.pharmacist_id", type: "number" },
            ]
      });
      const query=
      `
      select sa.sale_id,sa.shop_id,
     sum(d.selling_price*si.quantity) as total,
      sa.discount,
      sum(d.selling_price*si.quantity)-sa.discount as grand_total,
      p.pharmacist_id ,
      p.name as sold_by,
      c.name as customer_name,c.phone as customer_phone,
      sa.date as sold_on from sale as sa
      left join sale_item as si
      on sa.sale_id=si.sale_id
      left join pharmacist as p on p.pharmacist_id=sa.pharmacist_id
      left join shop as sh on sa.shop_id=sh.shop_id
      left join drug as d on si.drug_id=d.drug_id
      left join customer as c on c.customer_id=sa.customer_id
      group by sa.sale_id
      having sa.shop_id=? ${whereClause}
      order by sa.date desc
      limit ${limit} offset ${offset}
      `

      const [rows]=await db.execute(query,params);

      return res.status(200).json(new ApiResponse(200,rows,`Fetched sales !`))
      }catch(err){
        throw new ApiError(400,err.message);
      }

  }
)


const getDetailsOfSale=asyncHandler(
  async(req,res)=>{
    try{
      const {sale_id}=req.params;
      if(!sale_id) throw new ApiError(400,'sale_id is missing!')
    const query=
    `select d.drug_id,d.name,d.selling_price,si.quantity,p.pharmacist_id,p.name
    as sold_by,c.name as customer_name,c.phone as customer_phone  from
    sale as sa
    left join sale_item as si on si.sale_id=sa.sale_id
    left join drug as d on si.drug_id=d.drug_id
    left join pharmacist as p on sa.pharmacist_id=p.pharmacist_id
    left join customer as c on sa.customer_id=c.customer_id
    where sa.sale_id=?`
    const [rows]=await db.execute(query,[sale_id])
    return res.status(200).json(new ApiResponse(200,rows));

    }catch(err){
      throw new ApiError(400,err.message)
    }
  }
);


const getDateVsRevenue=asyncHandler(
  async(req,res)=>{
      try{
        const shop_id=await getShopImWorkingIn(req,res);
        const { limit, offset, whereClause, params } = buildPaginatedFilters({
            req,
            baseParams: [shop_id],
            allowedFilters: [
              { key: "year", column: "sa.date", type: "year" },
              { key: "month", column: "sa.date", type: "month" },
              { key: "day", column: "sa.date", type: "day" },
            ]
      });
        const query=
        `select x.sold_on as date,sum(x.grand_total) as net_revenue from (select sa.sale_id,sa.shop_id,sa.date as sold_on,sum(d.selling_price*q.quantity) as total,sa.discount,
        sum(d.selling_price*q.quantity)-sa.discount as grand_total
        from sale as sa left join sale_item as si on sa.sale_id=si.sale_id
        left join shop as sh on sa.shop_id=sh.shop_id
        left join drug as d on si.drug_id=d.drug_id
        left join quantity as q on d.drug_id=q.drug_id
        where sa.shop_id=? ${whereClause}
        group by sa.sale_id 
        order by sold_on limit ${limit} offset ${offset}) as x group by sold_on

`

      const [rows]=await db.execute(query,params);
      return res.status(200).json(new ApiResponse(200,rows,"Fetched!"));
      }catch(err){
        throw new ApiError(400,err.message);
      }
  }
);

const  getDateVsSale=asyncHandler(
  async(req,res)=>{
      try{
        const shop_id=await getShopImWorkingIn(req,res);
      const { limit, offset, whereClause, params } = buildPaginatedFilters({
            req,
            baseParams: [shop_id],
            allowedFilters: [
              { key: "year", column: "s.date", type: "year" },
              { key: "month", column: "s.date", type: "month" },
              { key: "day", column: "s.date", type: "day" },
            ]
      });
      const query=`
      SELECT 
      DATE(s.date) AS sale_date,
      HOUR(s.date) AS sale_hour,
      COUNT(s.sale_id) AS nSales,
      count(distinct s.customer_id) as nCustomers
      FROM sale AS s
      WHERE s.shop_id = ? ${whereClause}
      GROUP BY DATE(s.date), HOUR(s.date)
      ORDER BY sale_date, sale_hour
      limit ${limit} offset ${offset}
      `
      const [rows]=await db.execute(query,params);
      return res.status(200).json(new ApiResponse(200,rows,"Fetched date vs sales"))
      }catch(err){throw new ApiError(400,err.message)}
  }
)


export { initSale,getOverallSales,getDetailsOfSale, getDateVsRevenue , getDateVsSale};
