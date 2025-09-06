import { ApiError } from "./Api_Error.utils.js";

/**
 * Builds pagination and WHERE clause filters dynamically
 * @param {Object} options - Query options
 * @param {Object} options.req - Express request object
 * @param {Number} options.defaultLimit - Default page size (optional, default = 10)
 * @param {Array} options.baseParams - Initial params (e.g., [shop_id])
 * @param {Array} options.allowedFilters - Allowed filter definitions
 * 
 * Each filter definition = {
 *   key: "searchManufacturer",   // query param name
 *   column: "m.name",            // DB column to filter
 *   type: "string" | "number"    // type of filter
 * }
 */
export function buildPaginatedFilters({ req, defaultLimit = 10, baseParams = [], allowedFilters = [] }) {
  let { pgNo = 1, ...queryParams } = req.query;
  if (!pgNo && req.body.pgNo) pgNo = req.body.pgNo;
  const page = parseInt(pgNo, 10);
  if (isNaN(page) || page < 1) {
    throw new ApiError(400, "Page number must be a positive integer.");
  }

  const limit = defaultLimit;
  const offset = (page - 1) * limit;

  const filters = [];
  const params = [...baseParams];

  allowedFilters.forEach(({ key, column, type }) => {
    const value = queryParams[key];
    if (value && value.toString().trim() !== "") {
      if (type === "string") {
        filters.push(`LOWER(${column}) LIKE ?`);
        params.push(value.trim().toLowerCase() + "%");
      } else if (type === "number") {
        filters.push(`${column} = ?`);
        params.push(Number(value));
      }
    }
  });

  const whereClause = filters.length ? `AND ${filters.join(" AND ")}` : "";

  return { limit, offset, whereClause, params };
}
