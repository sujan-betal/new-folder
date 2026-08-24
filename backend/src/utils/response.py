from fastapi.responses import JSONResponse


class StatusCode:
    success = 200
    created = 201
    badRequest = 400
    unauthorized = 401
    forbidden = 403
    notFound = 404
    conflict = 409
    internalServerError = 500


def api_response_success(
    data=None,
    message: str = "Success",
    status_code: int = StatusCode.success,
):
    return JSONResponse(
        status_code=status_code,
        content={"success": True, "message": message, "data": data},
    )


def api_response_error(
    message: str = "Something went wrong",
    status_code: int = StatusCode.badRequest,
    data=None,
):
    return JSONResponse(
        status_code=status_code,
        content={"success": False, "message": message, "data": data},
    )
