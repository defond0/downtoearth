"""Exceptions for downtoearth.

These are helpers provided so that you can raise proper HTTP code errors from your API.

Usage:
    from downtoearth.exceptions import NotFoundException
    raise NotFoundException('your princess is in another castle')
"""
class BadRequestException(Exception):
    def __init__(self, msg):
        prefix = '[Bad Request]'
        super(BadRequestException, self).__init__(prefix + ' ' + msg)


class ConflictException(Exception):
    def __init__(self, msg):
        prefix = '[Conflict]'
        super(ConflictException, self).__init__(prefix + ' ' + msg)


class InternalServerErrorException(Exception):
    def __init__(self, msg):
        prefix = '[Internal Server Error]'
        super(InternalServerErrorException, self).__init__(prefix + ' ' + msg)


class NotFoundException(Exception):
    def __init__(self, msg):
        prefix = '[Not Found]'
        super(NotFoundException, self).__init__(prefix + ' ' + msg)


class NotImplementedException(Exception):
    def __init__(self, msg):
        prefix = '[Not Implemented]'
        super(NotImplementedException, self).__init__(prefix + ' ' + msg)
