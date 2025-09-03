import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { ApiError } from "../Utils/Api_Error.utils.js"
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { get_refresh_access_token } from "../Utils/token_generator.utils.js";
import { db } from "../Utils/sql_connection.utils.js";
import bcrypt from "bcrypt";


const pharmacistRegisteredAlready = async (email) => {
    const [rows] = await db.execute(
        "SELECT * FROM pharmacist WHERE email = ? limit 1",
        [email]
    );

    

    if (!rows) {
        throw new ApiError(500, "Failed to check if pharmacist is registered!");
    }

    return rows.length > 0; 
};

const registerPharmacist = asyncHandler(

    async (req, res) => {


        console.log("Receiving request body.....");
        const { email, password, name, dob, address, phone } = req.body;
        console.log(`recived body for post method register: ${JSON.stringify(req.body)}`);

        if (!email) throw new ApiError(400, "Email is empty!")

        console.log("Checking if pharmacist already exists.....");
        const alreadyExists = await pharmacistRegisteredAlready(email)
        console.log(`Pharmacist exists: ${alreadyExists}`);
        if (alreadyExists) throw new ApiError(400, "Pharmacist is already registered!")


        if ([email, password, name, dob, address, phone].some((e) => e === undefined || e?.trim?.() === "")) {
            throw new ApiError(400, "Some fields are empty or missing!");
        }





        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(password, saltRounds);





        console.log("Registering user in Database....");
        try {
            const query = `
            INSERT INTO pharmacist (name, dob, address, phone, password, email)
            VALUES (?, ?, ?, ?, ?, ?)
        `;
            const [result] = await db.execute(query, [
                name,
                dob,
                address,
                phone,
                hashedPassword,
                email,
            ]);

            if (result.affectedRows === 0) throw new ApiError(400, "Failed to register pharmacist.");

            return res.status(200).json(new ApiResponse(200, { userId: result.insertId }, "Pharmacist registered successfully.")
            );

        } catch (err) {
            throw new ApiError(500, `Database insert error: ${err.message}`);
        }

    }




);


const getPharmacistById = async (pharmacist_id) => {
    const query = 'select * from pharmacist where pharmacist_id=? limit 1'
    const [result] = await db.execute(query, [pharmacist_id])
    if (!result) throw ApiError(400, "Failed to fetch pharmacist detailss!")
    return result[0];
}


const loginPharmacist = asyncHandler(async (req, res) => {
    console.log("Fetching UI data for login...");
    console.log(`Body received for login: ${JSON.stringify(req.body)}`);

    const { email, password } = req.body;

    if (!(email && password)) {
        throw new ApiError(400, "Invalid Credentials!");
    }

    console.log("Checking if user is registered....");
    const isRegistered = await pharmacistRegisteredAlready(email);
    if (!isRegistered) throw new ApiError(400, "Please register before logging in!");

    
    const [rows] = await db.execute(
        `SELECT * 
     FROM pharmacist 
     WHERE email = ? 
     LIMIT 1`,
        [email]
    );

    if (rows.length === 0) {
        throw new ApiError(401, "Invalid email or password");
    }

    const pharmacist = rows[0];

    const isMatch = await bcrypt.compare(password, pharmacist.password);
    if (!isMatch) {
        throw new ApiError(401, "Invalid email or password");
    }

    delete pharmacist.password;

    console.log("Pharmacist login success");

    console.log("Starting generation of refresh token...");
    const { accessToken, refreshToken } = await get_refresh_access_token(pharmacist.pharmacist_id);

    console.log(`Sent these tokens as cookies for logged session....`);

    return res
        .status(200)
        .cookie("accessToken", accessToken, {
            httpOnly: true,   
            secure: process.env.NODE_ENV === "production"
        })
        .cookie("refreshToken", refreshToken, {
            httpOnly: true,
            secure: process.env.NODE_ENV === "production"
        })
        .json(
            new ApiResponse(
                200,
                { pharmacist: { ...pharmacist, refreshToken }, accessToken, refreshToken },
                "Login session created!"
            )
        );
});



const logoutPharmacist = asyncHandler(async (req, res) => {

  if (!req.pharmacist) {
    throw new ApiError(
      400,
      "JWT failed to append pharmacist field to request while logging out..."
    );
  }

  console.log("Clearing refresh token before logout...");

  
  const [result] = await db.execute(
    `UPDATE pharmacist SET refreshToken = NULL WHERE pharmacist_id = ?`,
    [req.pharmacist.pharmacist_id]
  );

  if (result.affectedRows === 0) {
    console.error("Failed to update pharmacist refresh token.");
    throw new ApiError(500, "Failed to update pharmacist refresh token.");
  }

  console.log("Refresh token cleared, logout success..");

  return res
    .status(200)
    .clearCookie("accessToken", { httpOnly: true, secure: false })
    .clearCookie("refreshToken", { httpOnly: true, secure: false })
    .json(
      new ApiResponse(
        200,
        { pharmacist_id: req.pharmacist.pharmacist_id },
        "Logout success"
      )
    );
});



/**Change password functionality */
const updatePassword = asyncHandler(async (req, res) => {
  const { oldPassword, newPassword } = req.body;
  const pharmacistId = req.pharmacist?.pharmacist_id;

  console.log("Change password method called...");

  if (!oldPassword || !newPassword) {
    throw new ApiError(400, "Old and new password are required!");
  }

  
  const [rows] = await db.execute(
    "SELECT password FROM pharmacist WHERE pharmacist_id = ? LIMIT 1",
    [pharmacistId]
  );

  if (rows.length === 0) {
    throw new ApiError(404, "Pharmacist not found!");
  }

  const pharmacist = rows[0];

  
  const validReq = await bcrypt.compare(oldPassword, pharmacist.password);
  if (!validReq) {
    throw new ApiError(400, "Incorrect old password!");
  }

  
  const saltRounds = 10;
  const hashedPassword = await bcrypt.hash(newPassword, saltRounds);

  
  const [result] = await db.execute(
    "UPDATE pharmacist SET password = ? WHERE pharmacist_id = ?",
    [hashedPassword, pharmacistId]
  );

  if (result.affectedRows === 0) {
    throw new ApiError(500, "Failed to update password!");
  }

  console.log("Password reset success...");
  return res
    .status(200)
    .json(new ApiResponse(200, {}, "Password reset success"));
});

/** Update full name functionality */
const updateName = asyncHandler(async (req, res) => {
  console.log("Update fullname method called...");

  const { newName } = req.body;
  const pharmacistId = req.pharmacist?.pharmacist_id;

  if (!newName) {
    throw new ApiError(400, "Invalid full name!");
  }

  
  const [result] = await db.execute(
    "UPDATE pharmacist SET name = ? WHERE pharmacist_id = ?",
    [newName, pharmacistId]
  );

  if (result.affectedRows === 0) {
    throw new ApiError(400, "Failed to update Full name!");
  }

  console.log("Full name updated...");
  return res
    .status(200)
    .json(new ApiResponse(200, { newfullName: newName }, "Full name updated successfully!"));
});





export { registerPharmacist, loginPharmacist, logoutPharmacist, updatePassword, updateName, getPharmacistById}