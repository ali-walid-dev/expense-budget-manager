sealed class Result<T> {
  const Result();
  R fold<R>({required R Function(T data) onOk, required R Function(Object e, StackTrace? st) onErr});
}

class Ok<T> extends Result<T> {
  const Ok(this.data);
  final T data;
  @override
  R fold<R>({required R Function(T data) onOk, required R Function(Object e, StackTrace? st) onErr}) => onOk(data);
}

class Err<T> extends Result<T> {
  const Err(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
  @override
  R fold<R>({required R Function(T data) onOk, required R Function(Object e, StackTrace? st) onErr}) => onErr(error, stackTrace);
}

extension ResultGuard<T> on Future<T> Function() {
  Future<Result<T>> guard() async {
    try {
      return Ok(await this());
    } catch (e, st) {
      return Err(e, st);
    }
  }
}
