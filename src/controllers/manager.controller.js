import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { buildPaginatedFilters } from "../Utils/paginated_query_builder.js";
import { db } from "../Utils/sql_connection.utils.js";
const isManager=asyncHandler(async(req,res)=>{res.status(200).json(new ApiResponse(200,"You have access to manager console!"))})
const getEmployeeDetails=asyncHandler(
    async(req,res)=>{
        try{
            const pharmacist_id=req.pharmacist.pharmacist_id;
            const shop_id=req.shop_id;
            const { limit, offset, whereClause, params } = buildPaginatedFilters({
                        req,
                        baseParams: [shop_id,shop_id],
                        allowedFilters: [
                            { key: "searchPharmacistByName", column: "p.name", type: "string" },
                            { key: "searchPharmacistById", column: "p.pharmacist_id", type: "number" },
                            { key: "searchPharmacistByEmail", column: "p.email", type: "string" }
                        ]
                });
            const query=
            `
            with cte as (select pharmacist_id,count(pharmacist_id) as cnt from sale  where shop_id=?
            group by pharmacist_id) 
            select e.emp_id,p.pharmacist_id,p.name as pharmacist_name,p.address as pharmacist_address,
            p.phone as pharmacist_phone,p.email as pharmacist_email,sal.salary as pharmacist_salary,
            case 
            when sh.manager_id=e.pharmacist_id then 'Manager'
            else 'Employee'
            end as 'Role',
            ifnull(cte.cnt,0) as nSalesMade
            from employee as e
            left join pharmacist as p
            on p.pharmacist_id=e.pharmacist_id
            left join salary as sal on sal.emp_id=e.emp_id
            left join shop as sh on sh.shop_id=e.shop_id
            left join cte on cte.pharmacist_id=e.pharmacist_id
            where e.shop_id=? ${whereClause}
            limit ${limit} offset ${offset}
            `
            const [rows]=await db.execute(query,params);
            if(rows.length===0) throw new ApiError(400,"Reached end of data!")
            return res.status(200).json(
                new ApiResponse(200,rows,"Fetched employee data !")
            )
        }catch(err){
            throw new ApiError(400,err.message)
        }
    }
);

const removeEmployee=asyncHandler(

    async(req,res)=>{
        try {
            const {id}=req.params;
            const query=`
            update employee
            set shop_id=null
            where pharmacist_id=?
            `
            console.log(`removing pharmacist_id${id} from shop...`);
            
            const [rows]=await db.execute(query,[id]);
            return res.status(200).json(new ApiResponse(200,rows,`deleted employee with id=${id}`))
        } catch (err) {
            throw new ApiError(400,err.message)
        }

    }
)
const updateEmployeeSalary=asyncHandler(

    async(req,res)=>{
        try {
            const {pharmacist_id,newSalary}=req.body;
            const query=`
            with cte as (select salary.emp_id as emp_id
            from salary
            left join employee on employee.emp_id=salary.emp_id
            left join pharmacist on employee.pharmacist_id=pharmacist.pharmacist_id
            where pharmacist.pharmacist_id=?)
            update salary 
            set salary=?
            where emp_id in (select emp_id from cte)
            `
            const [rows]=await db.execute(query,[pharmacist_id,newSalary]);
            return res.status(200).json(new ApiResponse(200,rows,`updated employee salary with id=${pharmacist_id}`))
        } catch (err) {
            throw new ApiError(400,err.message)
        }

    }
);
const getAllEmployables=asyncHandler(
    async(req,res)=>{
        const query=
        `select p.pharmacist_id,p.name,p.email,
        s.salary as prev_salary,
        CONCAT(
                TIMESTAMPDIFF(YEAR, p.joined_date, CURRENT_DATE), ' years ',
                MOD(TIMESTAMPDIFF(MONTH, p.joined_date, CURRENT_DATE), 12), ' months'
            ) AS experience
        from employee as e
        left join pharmacist as p 
        on e.pharmacist_id=p.pharmacist_id
        left join salary as s on s.emp_id=e.emp_id
        where e.shop_id is null
`
        const [rows]=await db.execute(query);
        if(rows.length==0) throw new ApiError(400,"No employables right now!")

    }
)
const addEmployee=asyncHandler(
    async(req,res)=>{
        const {pharmacist_id}=req.body;
        if(!pharmacist_id) throw new ApiError(400,"Pls provide id of pharmacist to add")
        console.log(`adding phamacist_id=${pharmacist_id} in shop_id=${req.shop_id}.....`);
        const query=`
            update employee
            set shop_id=?
            where pharmacist_id=?
            `
            const [rows]=await db.execute(query,[req.shop_id,pharmacist_id]);
        
        if(rows.length===0) throw new ApiError(400,"Failed to add employee!")
        return res.status(200).json(
            new ApiResponse(200,rows)
        )
        
    }
)

export {isManager,getEmployeeDetails,removeEmployee,updateEmployeeSalary,addEmployee}