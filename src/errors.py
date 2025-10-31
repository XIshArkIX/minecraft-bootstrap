class ApplicationError(RuntimeError):
    pass


class EnvironmentValidationError(ApplicationError):
    pass


class HttpRequestError(ApplicationError):
    pass


class ExtractionError(ApplicationError):
    pass


class DownloadError(ApplicationError):
    pass


class CurseForgeApiError(ApplicationError):
    pass


class ModpackDownloadError(ApplicationError):
    pass


class InvalidModpackFormatError(ApplicationError):
    pass


class ModpackExtractionError(ApplicationError):
    pass


class InstallationError(ApplicationError):
    pass
