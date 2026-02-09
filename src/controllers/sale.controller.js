import { db } from "../Utils/sql_connection.utils.js";
import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { getShopImWorkingIn } from "./shop.controller.js";

import { buildPaginatedFilters } from "../Utils/paginated_query_builder.js";
import { redis } from "../Utils/redis.connection.js";

const initSale = asyncHandler(async (req, res) => {
  const { pharmacist_id } = req.pharmacist;
  const shop_id = await getShopImWorkingIn(req, res);


  const { items, discount = 0, customer_id } = req.body;

  // console.log(JSON.stringify(req.body,null,2));
  /**{
  "items": [
    {
      "drug_id": 2,
      "quantity": 32
    },
    {
      "drug_id": 1,
      "quantity": 21
    }
  ],
  "discount": 0,
  "customer_id": 5
} */


  if (!Array.isArray(items) || items.length === 0) {
    throw new ApiError(400, "Provide items array with { drug_id, quantity }");
  }


  if (!customer_id) throw new ApiError(400, "Please provide customer id")



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

  let conn;

  try {
    conn = await db.getConnection();
    await conn.beginTransaction();

    const [saleResult] = await conn.execute(
      `INSERT INTO sale (shop_id, pharmacist_id, discount, customer_id)
     VALUES (?, ?, ?, ?)`,
      [shop_id, pharmacist_id, discount, customer_id]
    );

    const sale_id = saleResult.insertId;
    if (!sale_id) throw new ApiError(500, "Failed to create sale");

    const placeholders = items.map(() => "(?,?,?)").join(",");
    const values = items.flatMap(it => [sale_id, it.drug_id, it.quantity]);

    await conn.execute(
      `INSERT INTO sale_item (sale_id, drug_id, quantity)
     VALUES ${placeholders}`,
      values
    );
    await conn.execute(`DROP TEMPORARY TABLE IF EXISTS temp_stock`);
    await conn.execute(`
    CREATE TEMPORARY TABLE temp_stock (
      drug_id INT NOT NULL,
      quantity INT NOT NULL,
      PRIMARY KEY (drug_id)
    ) ENGINE=MEMORY
  `);

    const tempPlaceholders = items.map(() => "(?, ?)").join(",");
    const tempValues = items.flatMap(it => [it.drug_id, it.quantity]);

    await conn.execute(
      `INSERT INTO temp_stock (drug_id, quantity)
     VALUES ${tempPlaceholders}
     ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`,
      tempValues
    );

    const [upd] = await conn.execute(
      `
    UPDATE quantity q
    JOIN temp_stock t ON q.drug_id = t.drug_id
    SET q.quantity = q.quantity - t.quantity
    WHERE q.shop_id = ?
      AND q.quantity >= t.quantity
    `,
      [shop_id]
    );

    const [[{ cnt }]] = await conn.execute(
      `SELECT COUNT(*) AS cnt FROM temp_stock`
    );

    if (upd.affectedRows !== cnt) {
      throw new ApiError(400, "Insufficient stock for one or more drugs");
    }

    await conn.commit();

    
    return res.status(200).json(
      new ApiResponse(
        200,
        "Sale created successfully"
      )
    );
  } catch (err) {
    if (conn) await conn.rollback();
    if (err instanceof ApiError) throw err;
    throw new ApiError(500, err.message || "Database error during sale creation");
  } finally {
    if (conn) conn.release()
  }
});




const getOverallSales = asyncHandler(
  async (req, res) => {

    try {
      const shop_id = await getShopImWorkingIn(req, res);
      const { limit, offset, whereClause, params } = buildPaginatedFilters({
        req,
        baseParams: [shop_id],
        allowedFilters: [
          { key: "searchByName", column: "p.name", type: "string" },
          { key: "searchBySaleId", column: "sa.sale_id", type: "number" },
          { key: "searchByPharmacistId", column: "p.pharmacist_id", type: "number" },
        ]
      });
      const query =
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

      const key = `getOverallSales:${whereClause}:${limit}:${offset}`
      const cache = await redis.get(key)
      if (cache) return res.status(200).json(new ApiResponse(200, JSON.parse(cache), "Fetched overall sales from redis"))


      const [rows] = await db.execute(query, params);

      await redis.set(key, JSON.stringify(rows))
      await redis.expire(key, 60)

      return res.status(200).json(new ApiResponse(200, rows, `Fetched sales !`))
    } catch (err) {
      throw new ApiError(400, err.message);
    }

  }
)


const getDetailsOfSale = asyncHandler(
  async (req, res) => {
    try {
      const { sale_id } = req.params;
      if (!sale_id) throw new ApiError(400, 'sale_id is missing!')

      const key = `getDetailsOfSale:${sale_id}`
      const cache = await redis.get(key)
      if (cache) return res.status(200).json(new ApiResponse(200, JSON.parse(cache), "Fetched from redis"))

      const query =
        `select d.drug_id,d.name,d.selling_price,si.quantity,p.pharmacist_id,p.name
    as sold_by,c.name as customer_name,c.phone as customer_phone  from
    sale as sa
    left join sale_item as si on si.sale_id=sa.sale_id
    left join drug as d on si.drug_id=d.drug_id
    left join pharmacist as p on sa.pharmacist_id=p.pharmacist_id
    left join customer as c on sa.customer_id=c.customer_id
    where sa.sale_id=?`
      const [rows] = await db.execute(query, [sale_id])

      await redis.set(key, JSON.stringify(rows))
      await redis.expire(key, 30)

      return res.status(200).json(new ApiResponse(200, rows));

    } catch (err) {
      throw new ApiError(400, err.message)
    }
  }
);


const getDateVsRevenue = asyncHandler(
  async (req, res) => {
    try {
      const shop_id = await getShopImWorkingIn(req, res);
      const { limit, offset, whereClause, params } = buildPaginatedFilters({
        req,
        baseParams: [shop_id],
        allowedFilters: [
          { key: "year", column: "sa.date", type: "year" },
          { key: "month", column: "sa.date", type: "month" },
          { key: "day", column: "sa.date", type: "day" },
        ]
      });


      const key = `getDateVsRevenue:${whereClause}:${limit}:${offset}:${params}`
      const cache = await redis.get(key)
      if (cache) return res.status(200).json(new ApiResponse(200, JSON.parse(cache), "Fetched date vs revenue from redis!"))


      const query =
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

      const [rows] = await db.execute(query, params);


      await redis.set(key, JSON.stringify(rows))
      await redis.expire(key, 60)



      return res.status(200).json(new ApiResponse(200, rows, "Fetched date vs revenue!"));
    } catch (err) {
      throw new ApiError(400, err.message);
    }
  }
);

const getDateVsSale = asyncHandler(
  async (req, res) => {
    try {
      const shop_id = await getShopImWorkingIn(req, res);
      const { limit, offset, whereClause, params } = buildPaginatedFilters({
        req,
        baseParams: [shop_id],
        allowedFilters: [
          { key: "year", column: "s.date", type: "year" },
          { key: "month", column: "s.date", type: "month" },
          { key: "day", column: "s.date", type: "day" },
        ]
      });

      const key = `getDateVsSale:${whereClause}:${limit}:${offset}:${params}`
      const cache = await redis.get(key)
      if (cache) return res.status(200).json(new ApiResponse(200, JSON.parse(cache), "Fetched date vs sale from redis!"))

      const query = `
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
      const [rows] = await db.execute(query, params);

      await redis.set(key, JSON.stringify(rows))
      await redis.expire(key, 60)


      return res.status(200).json(new ApiResponse(200, rows, "Fetched date vs sales"))
    } catch (err) { throw new ApiError(400, err.message) }
  }
)

const defaultDateRange = () => {
  const end = new Date();
  const start = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  return {
    startDate: start.toISOString().slice(0, 10),
    endDate: end.toISOString().slice(0, 10),
  };
};

const discountUsage = asyncHandler(async (req, res) => {
  try {
    const shop_id = await getShopImWorkingIn(req, res);
    const { startDate, endDate } = req.params.startDate
      ? { startDate: req.params.startDate, endDate: req.params.endDate || new Date().toISOString().slice(0, 10) }
      : defaultDateRange();


    const key = `discountUsage:${shop_id}:${startDate}:${endDate}`
    const cache = await redis.get(key)
    if (cache) return res.status(200).json(new ApiResponse(200, JSON.parse(cache), "Fetch discount usage from redis!"))

    const query = `
      SELECT discount, COUNT(*) AS nSales, COALESCE(SUM(si.quantity * d.selling_price),0) AS revenue
      FROM sale s
      LEFT JOIN sale_item si ON si.sale_id = s.sale_id
      LEFT JOIN drug d ON d.drug_id = si.drug_id
      WHERE s.shop_id = ?
        AND date(s.date) BETWEEN ? AND ?
      GROUP BY discount
      ORDER BY discount DESC;
    `;

    const [rows] = await db.execute(query, [shop_id, startDate, endDate]);

    await redis.set(key, JSON.stringify(rows))
    await redis.expire(key, 60)


    return res.status(200).json(new ApiResponse(200, rows, "Discount usage fetched"));
  } catch (err) {
    throw new ApiError(400, `Failed to fetch discount usage: ${err.message}`);
  }
});


export { initSale, getOverallSales, getDetailsOfSale, getDateVsRevenue, getDateVsSale, discountUsage };
