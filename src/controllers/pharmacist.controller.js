import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { ApiError } from "../Utils/Api_Error.utils.js"
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { get_refresh_access_token } from "../Utils/token_generator.utils.js";
import { db } from "../Utils/sql_connection.utils.js";



const pharmacistRegisteredAlready = async (email) => {
    const [rows] = await db.execute(
        "SELECT * FROM pharmacist WHERE email = ? limit 1",
        [email]
    );

    // console.log("Query result:", rows); // rows will be an array of objects

    if (!rows) {
        throw new ApiError(500, "Failed to check if pharmacist is registered!");
    }

    return rows.length > 0; // true if found, false if not
};
import bcrypt from "bcrypt";
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

    // ✅ Fetch pharmacist by email
    const [rows] = await db.execute(
        `SELECT pharmacist_id, name, dob, address, phone, email, password, refreshToken 
     FROM pharmacist 
     WHERE email = ? 
     LIMIT 1`,
        [email]
    );

    if (rows.length === 0) {
        throw new ApiError(401, "Invalid email or password");
    }

    const pharmacist = rows[0];

    // ✅ Compare entered password with hashed password
    const isMatch = await bcrypt.compare(password, pharmacist.password);
    if (!isMatch) {
        throw new ApiError(401, "Invalid email or password");
    }

    // ✅ Remove password before sending pharmacist object back
    delete pharmacist.password;

    console.log("User login success");

    console.log("Starting generation of refresh token...");
    const { accessToken, refreshToken } = await get_refresh_access_token(pharmacist.pharmacist_id);

    console.log(`Sent these tokens as cookies for logged session....`);

    return res
        .status(200)
        .cookie("accessToken", accessToken, {
            httpOnly: true,   // ✅ more secure
            secure: process.env.NODE_ENV === "production"
        })
        .cookie("refreshToken", refreshToken, {
            httpOnly: true,
            secure: process.env.NODE_ENV === "production"
        })
        .json(
            new ApiResponse(
                200,
                { pharmacist, accessToken, refreshToken },
                "Login session created!"
            )
        );
});



const logoutUser = asyncHandler(
    async (req, res) => {
        if (!req.user) {
            throw new ApiError(400, "JWT failed to append user field to request while logging out...")
        }
        console.log("User field avaliable in req now...");

        console.log("Setting access token of user to undefined bfr logout...");

        const updatedUser = await User.findByIdAndUpdate(
            req.user._id,
            {
                $unset: {
                    refreshToken: 1
                }
            },
            {
                new: true,
            }
        )

        if (!updatedUser) {
            console.error("Failed to update user refresh token.");
            throw new ApiError(500, "Failed to update user refresh token.");
        }

        console.log("Set refresh token to undefined, logout sucess..");

        return res
            .status(200)
            .clearCookie("accessToken", { httpOnly: true, secure: false })
            .clearCookie("refreshToken", { httpOnly: true, secure: false })
            .json(
                new ApiResponse(
                    200,
                    updatedUser,
                    "Logout success"
                )
            )
    }
)

const refreshAccessToken = asyncHandler(async (req, res) => {
    const incomingRefreshToken = req.cookies.refreshToken || req.body.refreshToken

    if (!incomingRefreshToken) {
        throw new ApiError(401, "unauthorized request")
    }

    try {
        const decodedToken = jwt.verify(
            incomingRefreshToken,
            process.env.REFRESH_TOKEN_SECRET
        )

        const user = await User.findById(decodedToken?._id)

        if (!user) {
            throw new ApiError(401, "Invalid refresh token")
        }

        if (incomingRefreshToken !== user?.refreshToken) {
            throw new ApiError(401, "Refresh token is expired or used")

        }

        const options = {
            httpOnly: true,
            secure: true
        }

        const { accessToken, newRefreshToken } = await generateAccessAndRefereshTokens(user._id)

        return res
            .status(200)
            .cookie("accessToken", accessToken, options)
            .cookie("refreshToken", newRefreshToken, options)
            .json(
                new ApiResponse(
                    200,
                    { accessToken, refreshToken: newRefreshToken },
                    "Access token refreshed"
                )
            )
    } catch (error) {
        throw new ApiError(401, error?.message || "Invalid refresh token")
    }

})

/**Change password functionality */

const updatePassword = asyncHandler(
    async (req, res) => {

        const { oldPassword, newPassword } = req.body;

        console.log("Change password method called...");

        const user = await User.findById(req.user._id);
        const validReq = await user.isPasswordCorrect(oldPassword);

        if (!validReq) {
            throw new ApiError(400, "Incorrect old password!");
        }
        console.log("Saving new password...");
        user.password = newPassword
        await user.save({ validateBeforeSave: false })
        console.log("Password reset success...");
        return res
            .status(200)
            .json(
                new ApiResponse(
                    200,
                    "Password reset success"
                )
            )
    }
)
/**Update full name func */
const updateFullName = asyncHandler(
    async (req, res) => {
        console.log("Upadate fullname method called...");
        const { newFullName } = req.body;
        if (!newFullName) {
            throw new ApiError(400, "Invalid full name!")
        }
        console.log("Updating full name....");
        const updatedUser = await User.findByIdAndUpdate(
            req.user._id,
            {
                $set: {
                    fullName: newFullName
                }
            },
            {
                new: true
            }
        )
        if (!updatedUser) {
            throw new ApiError(400, "Failed to update Full name!")
        }
        console.log("full name updated...");
        return res
            .status(200)
            .json(
                new ApiResponse(
                    200,
                    updatedUser,
                    "Full name updated suceessfully!"
                )
            )
    }
)




export { registerPharmacist, loginPharmacist, logoutUser, refreshAccessToken, updatePassword, updateFullName, getPharmacistById }