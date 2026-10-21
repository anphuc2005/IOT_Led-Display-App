import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class NavigationEvent extends Equatable {
  const NavigationEvent();
  @override
  List<Object> get props => [];
}

final class NavigationTabSelected extends NavigationEvent {
  final int index;
  const NavigationTabSelected(this.index);
  @override
  List<Object> get props => [index];
}

class NavigationState extends Equatable {
  final int index;
  const NavigationState(this.index);
  @override
  List<Object> get props => [index];
}

class NavigationBloc extends Bloc<NavigationEvent, NavigationState> {
  NavigationBloc() : super(const NavigationState(0)) {
    on<NavigationTabSelected>((event, emit) {
      if (event.index >= 0 && event.index < 5) {
        emit(NavigationState(event.index));
      }
    });
  }
}
