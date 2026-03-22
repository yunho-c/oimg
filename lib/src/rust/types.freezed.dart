// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CropSpec {

 int get width; int get height;
/// Create a copy of CropSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CropSpecCopyWith<CropSpec> get copyWith => _$CropSpecCopyWithImpl<CropSpec>(this as CropSpec, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CropSpec&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'CropSpec(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $CropSpecCopyWith<$Res>  {
  factory $CropSpecCopyWith(CropSpec value, $Res Function(CropSpec) _then) = _$CropSpecCopyWithImpl;
@useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$CropSpecCopyWithImpl<$Res>
    implements $CropSpecCopyWith<$Res> {
  _$CropSpecCopyWithImpl(this._self, this._then);

  final CropSpec _self;
  final $Res Function(CropSpec) _then;

/// Create a copy of CropSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? width = null,Object? height = null,}) {
  return _then(_self.copyWith(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CropSpec].
extension CropSpecPatterns on CropSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( CropSpec_Region value)?  region,TResult Function( CropSpec_AspectRatio value)?  aspectRatio,required TResult orElse(),}){
final _that = this;
switch (_that) {
case CropSpec_Region() when region != null:
return region(_that);case CropSpec_AspectRatio() when aspectRatio != null:
return aspectRatio(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( CropSpec_Region value)  region,required TResult Function( CropSpec_AspectRatio value)  aspectRatio,}){
final _that = this;
switch (_that) {
case CropSpec_Region():
return region(_that);case CropSpec_AspectRatio():
return aspectRatio(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( CropSpec_Region value)?  region,TResult? Function( CropSpec_AspectRatio value)?  aspectRatio,}){
final _that = this;
switch (_that) {
case CropSpec_Region() when region != null:
return region(_that);case CropSpec_AspectRatio() when aspectRatio != null:
return aspectRatio(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int x,  int y,  int width,  int height)?  region,TResult Function( int width,  int height)?  aspectRatio,required TResult orElse(),}) {final _that = this;
switch (_that) {
case CropSpec_Region() when region != null:
return region(_that.x,_that.y,_that.width,_that.height);case CropSpec_AspectRatio() when aspectRatio != null:
return aspectRatio(_that.width,_that.height);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int x,  int y,  int width,  int height)  region,required TResult Function( int width,  int height)  aspectRatio,}) {final _that = this;
switch (_that) {
case CropSpec_Region():
return region(_that.x,_that.y,_that.width,_that.height);case CropSpec_AspectRatio():
return aspectRatio(_that.width,_that.height);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int x,  int y,  int width,  int height)?  region,TResult? Function( int width,  int height)?  aspectRatio,}) {final _that = this;
switch (_that) {
case CropSpec_Region() when region != null:
return region(_that.x,_that.y,_that.width,_that.height);case CropSpec_AspectRatio() when aspectRatio != null:
return aspectRatio(_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc


class CropSpec_Region extends CropSpec {
  const CropSpec_Region({required this.x, required this.y, required this.width, required this.height}): super._();
  

 final  int x;
 final  int y;
@override final  int width;
@override final  int height;

/// Create a copy of CropSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CropSpec_RegionCopyWith<CropSpec_Region> get copyWith => _$CropSpec_RegionCopyWithImpl<CropSpec_Region>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CropSpec_Region&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,x,y,width,height);

@override
String toString() {
  return 'CropSpec.region(x: $x, y: $y, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $CropSpec_RegionCopyWith<$Res> implements $CropSpecCopyWith<$Res> {
  factory $CropSpec_RegionCopyWith(CropSpec_Region value, $Res Function(CropSpec_Region) _then) = _$CropSpec_RegionCopyWithImpl;
@override @useResult
$Res call({
 int x, int y, int width, int height
});




}
/// @nodoc
class _$CropSpec_RegionCopyWithImpl<$Res>
    implements $CropSpec_RegionCopyWith<$Res> {
  _$CropSpec_RegionCopyWithImpl(this._self, this._then);

  final CropSpec_Region _self;
  final $Res Function(CropSpec_Region) _then;

/// Create a copy of CropSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,Object? width = null,Object? height = null,}) {
  return _then(CropSpec_Region(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as int,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class CropSpec_AspectRatio extends CropSpec {
  const CropSpec_AspectRatio({required this.width, required this.height}): super._();
  

@override final  int width;
@override final  int height;

/// Create a copy of CropSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CropSpec_AspectRatioCopyWith<CropSpec_AspectRatio> get copyWith => _$CropSpec_AspectRatioCopyWithImpl<CropSpec_AspectRatio>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CropSpec_AspectRatio&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'CropSpec.aspectRatio(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $CropSpec_AspectRatioCopyWith<$Res> implements $CropSpecCopyWith<$Res> {
  factory $CropSpec_AspectRatioCopyWith(CropSpec_AspectRatio value, $Res Function(CropSpec_AspectRatio) _then) = _$CropSpec_AspectRatioCopyWithImpl;
@override @useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$CropSpec_AspectRatioCopyWithImpl<$Res>
    implements $CropSpec_AspectRatioCopyWith<$Res> {
  _$CropSpec_AspectRatioCopyWithImpl(this._self, this._then);

  final CropSpec_AspectRatio _self;
  final $Res Function(CropSpec_AspectRatio) _then;

/// Create a copy of CropSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,}) {
  return _then(CropSpec_AspectRatio(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$ExtendSpec {

 int get width; int get height;
/// Create a copy of ExtendSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExtendSpecCopyWith<ExtendSpec> get copyWith => _$ExtendSpecCopyWithImpl<ExtendSpec>(this as ExtendSpec, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExtendSpec&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'ExtendSpec(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $ExtendSpecCopyWith<$Res>  {
  factory $ExtendSpecCopyWith(ExtendSpec value, $Res Function(ExtendSpec) _then) = _$ExtendSpecCopyWithImpl;
@useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$ExtendSpecCopyWithImpl<$Res>
    implements $ExtendSpecCopyWith<$Res> {
  _$ExtendSpecCopyWithImpl(this._self, this._then);

  final ExtendSpec _self;
  final $Res Function(ExtendSpec) _then;

/// Create a copy of ExtendSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? width = null,Object? height = null,}) {
  return _then(_self.copyWith(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ExtendSpec].
extension ExtendSpecPatterns on ExtendSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ExtendSpec_AspectRatio value)?  aspectRatio,TResult Function( ExtendSpec_Size value)?  size,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ExtendSpec_AspectRatio() when aspectRatio != null:
return aspectRatio(_that);case ExtendSpec_Size() when size != null:
return size(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ExtendSpec_AspectRatio value)  aspectRatio,required TResult Function( ExtendSpec_Size value)  size,}){
final _that = this;
switch (_that) {
case ExtendSpec_AspectRatio():
return aspectRatio(_that);case ExtendSpec_Size():
return size(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ExtendSpec_AspectRatio value)?  aspectRatio,TResult? Function( ExtendSpec_Size value)?  size,}){
final _that = this;
switch (_that) {
case ExtendSpec_AspectRatio() when aspectRatio != null:
return aspectRatio(_that);case ExtendSpec_Size() when size != null:
return size(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int width,  int height)?  aspectRatio,TResult Function( int width,  int height)?  size,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ExtendSpec_AspectRatio() when aspectRatio != null:
return aspectRatio(_that.width,_that.height);case ExtendSpec_Size() when size != null:
return size(_that.width,_that.height);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int width,  int height)  aspectRatio,required TResult Function( int width,  int height)  size,}) {final _that = this;
switch (_that) {
case ExtendSpec_AspectRatio():
return aspectRatio(_that.width,_that.height);case ExtendSpec_Size():
return size(_that.width,_that.height);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int width,  int height)?  aspectRatio,TResult? Function( int width,  int height)?  size,}) {final _that = this;
switch (_that) {
case ExtendSpec_AspectRatio() when aspectRatio != null:
return aspectRatio(_that.width,_that.height);case ExtendSpec_Size() when size != null:
return size(_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc


class ExtendSpec_AspectRatio extends ExtendSpec {
  const ExtendSpec_AspectRatio({required this.width, required this.height}): super._();
  

@override final  int width;
@override final  int height;

/// Create a copy of ExtendSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExtendSpec_AspectRatioCopyWith<ExtendSpec_AspectRatio> get copyWith => _$ExtendSpec_AspectRatioCopyWithImpl<ExtendSpec_AspectRatio>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExtendSpec_AspectRatio&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'ExtendSpec.aspectRatio(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $ExtendSpec_AspectRatioCopyWith<$Res> implements $ExtendSpecCopyWith<$Res> {
  factory $ExtendSpec_AspectRatioCopyWith(ExtendSpec_AspectRatio value, $Res Function(ExtendSpec_AspectRatio) _then) = _$ExtendSpec_AspectRatioCopyWithImpl;
@override @useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$ExtendSpec_AspectRatioCopyWithImpl<$Res>
    implements $ExtendSpec_AspectRatioCopyWith<$Res> {
  _$ExtendSpec_AspectRatioCopyWithImpl(this._self, this._then);

  final ExtendSpec_AspectRatio _self;
  final $Res Function(ExtendSpec_AspectRatio) _then;

/// Create a copy of ExtendSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,}) {
  return _then(ExtendSpec_AspectRatio(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ExtendSpec_Size extends ExtendSpec {
  const ExtendSpec_Size({required this.width, required this.height}): super._();
  

@override final  int width;
@override final  int height;

/// Create a copy of ExtendSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExtendSpec_SizeCopyWith<ExtendSpec_Size> get copyWith => _$ExtendSpec_SizeCopyWithImpl<ExtendSpec_Size>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExtendSpec_Size&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'ExtendSpec.size(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $ExtendSpec_SizeCopyWith<$Res> implements $ExtendSpecCopyWith<$Res> {
  factory $ExtendSpec_SizeCopyWith(ExtendSpec_Size value, $Res Function(ExtendSpec_Size) _then) = _$ExtendSpec_SizeCopyWithImpl;
@override @useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$ExtendSpec_SizeCopyWithImpl<$Res>
    implements $ExtendSpec_SizeCopyWith<$Res> {
  _$ExtendSpec_SizeCopyWithImpl(this._self, this._then);

  final ExtendSpec_Size _self;
  final $Res Function(ExtendSpec_Size) _then;

/// Create a copy of ExtendSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,}) {
  return _then(ExtendSpec_Size(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$FillSpec {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FillSpec);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FillSpec()';
}


}

/// @nodoc
class $FillSpecCopyWith<$Res>  {
$FillSpecCopyWith(FillSpec _, $Res Function(FillSpec) __);
}


/// Adds pattern-matching-related methods to [FillSpec].
extension FillSpecPatterns on FillSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FillSpec_Solid value)?  solid,TResult Function( FillSpec_Transparent value)?  transparent,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FillSpec_Solid() when solid != null:
return solid(_that);case FillSpec_Transparent() when transparent != null:
return transparent(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FillSpec_Solid value)  solid,required TResult Function( FillSpec_Transparent value)  transparent,}){
final _that = this;
switch (_that) {
case FillSpec_Solid():
return solid(_that);case FillSpec_Transparent():
return transparent(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FillSpec_Solid value)?  solid,TResult? Function( FillSpec_Transparent value)?  transparent,}){
final _that = this;
switch (_that) {
case FillSpec_Solid() when solid != null:
return solid(_that);case FillSpec_Transparent() when transparent != null:
return transparent(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int r,  int g,  int b,  int a)?  solid,TResult Function()?  transparent,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FillSpec_Solid() when solid != null:
return solid(_that.r,_that.g,_that.b,_that.a);case FillSpec_Transparent() when transparent != null:
return transparent();case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int r,  int g,  int b,  int a)  solid,required TResult Function()  transparent,}) {final _that = this;
switch (_that) {
case FillSpec_Solid():
return solid(_that.r,_that.g,_that.b,_that.a);case FillSpec_Transparent():
return transparent();}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int r,  int g,  int b,  int a)?  solid,TResult? Function()?  transparent,}) {final _that = this;
switch (_that) {
case FillSpec_Solid() when solid != null:
return solid(_that.r,_that.g,_that.b,_that.a);case FillSpec_Transparent() when transparent != null:
return transparent();case _:
  return null;

}
}

}

/// @nodoc


class FillSpec_Solid extends FillSpec {
  const FillSpec_Solid({required this.r, required this.g, required this.b, required this.a}): super._();
  

 final  int r;
 final  int g;
 final  int b;
 final  int a;

/// Create a copy of FillSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FillSpec_SolidCopyWith<FillSpec_Solid> get copyWith => _$FillSpec_SolidCopyWithImpl<FillSpec_Solid>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FillSpec_Solid&&(identical(other.r, r) || other.r == r)&&(identical(other.g, g) || other.g == g)&&(identical(other.b, b) || other.b == b)&&(identical(other.a, a) || other.a == a));
}


@override
int get hashCode => Object.hash(runtimeType,r,g,b,a);

@override
String toString() {
  return 'FillSpec.solid(r: $r, g: $g, b: $b, a: $a)';
}


}

/// @nodoc
abstract mixin class $FillSpec_SolidCopyWith<$Res> implements $FillSpecCopyWith<$Res> {
  factory $FillSpec_SolidCopyWith(FillSpec_Solid value, $Res Function(FillSpec_Solid) _then) = _$FillSpec_SolidCopyWithImpl;
@useResult
$Res call({
 int r, int g, int b, int a
});




}
/// @nodoc
class _$FillSpec_SolidCopyWithImpl<$Res>
    implements $FillSpec_SolidCopyWith<$Res> {
  _$FillSpec_SolidCopyWithImpl(this._self, this._then);

  final FillSpec_Solid _self;
  final $Res Function(FillSpec_Solid) _then;

/// Create a copy of FillSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? r = null,Object? g = null,Object? b = null,Object? a = null,}) {
  return _then(FillSpec_Solid(
r: null == r ? _self.r : r // ignore: cast_nullable_to_non_nullable
as int,g: null == g ? _self.g : g // ignore: cast_nullable_to_non_nullable
as int,b: null == b ? _self.b : b // ignore: cast_nullable_to_non_nullable
as int,a: null == a ? _self.a : a // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FillSpec_Transparent extends FillSpec {
  const FillSpec_Transparent(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FillSpec_Transparent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FillSpec.transparent()';
}


}




/// @nodoc
mixin _$ImageOperation {

 Object get field0;



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageOperation&&const DeepCollectionEquality().equals(other.field0, field0));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(field0));

@override
String toString() {
  return 'ImageOperation(field0: $field0)';
}


}

/// @nodoc
class $ImageOperationCopyWith<$Res>  {
$ImageOperationCopyWith(ImageOperation _, $Res Function(ImageOperation) __);
}


/// Adds pattern-matching-related methods to [ImageOperation].
extension ImageOperationPatterns on ImageOperation {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ImageOperation_Convert value)?  convert,TResult Function( ImageOperation_Optimize value)?  optimize,TResult Function( ImageOperation_Resize value)?  resize,TResult Function( ImageOperation_Crop value)?  crop,TResult Function( ImageOperation_Extend value)?  extend,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ImageOperation_Convert() when convert != null:
return convert(_that);case ImageOperation_Optimize() when optimize != null:
return optimize(_that);case ImageOperation_Resize() when resize != null:
return resize(_that);case ImageOperation_Crop() when crop != null:
return crop(_that);case ImageOperation_Extend() when extend != null:
return extend(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ImageOperation_Convert value)  convert,required TResult Function( ImageOperation_Optimize value)  optimize,required TResult Function( ImageOperation_Resize value)  resize,required TResult Function( ImageOperation_Crop value)  crop,required TResult Function( ImageOperation_Extend value)  extend,}){
final _that = this;
switch (_that) {
case ImageOperation_Convert():
return convert(_that);case ImageOperation_Optimize():
return optimize(_that);case ImageOperation_Resize():
return resize(_that);case ImageOperation_Crop():
return crop(_that);case ImageOperation_Extend():
return extend(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ImageOperation_Convert value)?  convert,TResult? Function( ImageOperation_Optimize value)?  optimize,TResult? Function( ImageOperation_Resize value)?  resize,TResult? Function( ImageOperation_Crop value)?  crop,TResult? Function( ImageOperation_Extend value)?  extend,}){
final _that = this;
switch (_that) {
case ImageOperation_Convert() when convert != null:
return convert(_that);case ImageOperation_Optimize() when optimize != null:
return optimize(_that);case ImageOperation_Resize() when resize != null:
return resize(_that);case ImageOperation_Crop() when crop != null:
return crop(_that);case ImageOperation_Extend() when extend != null:
return extend(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( ConvertOptions field0)?  convert,TResult Function( OptimizeOptions field0)?  optimize,TResult Function( ResizeOptions field0)?  resize,TResult Function( CropOptions field0)?  crop,TResult Function( ExtendOptions field0)?  extend,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ImageOperation_Convert() when convert != null:
return convert(_that.field0);case ImageOperation_Optimize() when optimize != null:
return optimize(_that.field0);case ImageOperation_Resize() when resize != null:
return resize(_that.field0);case ImageOperation_Crop() when crop != null:
return crop(_that.field0);case ImageOperation_Extend() when extend != null:
return extend(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( ConvertOptions field0)  convert,required TResult Function( OptimizeOptions field0)  optimize,required TResult Function( ResizeOptions field0)  resize,required TResult Function( CropOptions field0)  crop,required TResult Function( ExtendOptions field0)  extend,}) {final _that = this;
switch (_that) {
case ImageOperation_Convert():
return convert(_that.field0);case ImageOperation_Optimize():
return optimize(_that.field0);case ImageOperation_Resize():
return resize(_that.field0);case ImageOperation_Crop():
return crop(_that.field0);case ImageOperation_Extend():
return extend(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( ConvertOptions field0)?  convert,TResult? Function( OptimizeOptions field0)?  optimize,TResult? Function( ResizeOptions field0)?  resize,TResult? Function( CropOptions field0)?  crop,TResult? Function( ExtendOptions field0)?  extend,}) {final _that = this;
switch (_that) {
case ImageOperation_Convert() when convert != null:
return convert(_that.field0);case ImageOperation_Optimize() when optimize != null:
return optimize(_that.field0);case ImageOperation_Resize() when resize != null:
return resize(_that.field0);case ImageOperation_Crop() when crop != null:
return crop(_that.field0);case ImageOperation_Extend() when extend != null:
return extend(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class ImageOperation_Convert extends ImageOperation {
  const ImageOperation_Convert(this.field0): super._();
  

@override final  ConvertOptions field0;

/// Create a copy of ImageOperation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageOperation_ConvertCopyWith<ImageOperation_Convert> get copyWith => _$ImageOperation_ConvertCopyWithImpl<ImageOperation_Convert>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageOperation_Convert&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ImageOperation.convert(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ImageOperation_ConvertCopyWith<$Res> implements $ImageOperationCopyWith<$Res> {
  factory $ImageOperation_ConvertCopyWith(ImageOperation_Convert value, $Res Function(ImageOperation_Convert) _then) = _$ImageOperation_ConvertCopyWithImpl;
@useResult
$Res call({
 ConvertOptions field0
});




}
/// @nodoc
class _$ImageOperation_ConvertCopyWithImpl<$Res>
    implements $ImageOperation_ConvertCopyWith<$Res> {
  _$ImageOperation_ConvertCopyWithImpl(this._self, this._then);

  final ImageOperation_Convert _self;
  final $Res Function(ImageOperation_Convert) _then;

/// Create a copy of ImageOperation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ImageOperation_Convert(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as ConvertOptions,
  ));
}


}

/// @nodoc


class ImageOperation_Optimize extends ImageOperation {
  const ImageOperation_Optimize(this.field0): super._();
  

@override final  OptimizeOptions field0;

/// Create a copy of ImageOperation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageOperation_OptimizeCopyWith<ImageOperation_Optimize> get copyWith => _$ImageOperation_OptimizeCopyWithImpl<ImageOperation_Optimize>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageOperation_Optimize&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ImageOperation.optimize(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ImageOperation_OptimizeCopyWith<$Res> implements $ImageOperationCopyWith<$Res> {
  factory $ImageOperation_OptimizeCopyWith(ImageOperation_Optimize value, $Res Function(ImageOperation_Optimize) _then) = _$ImageOperation_OptimizeCopyWithImpl;
@useResult
$Res call({
 OptimizeOptions field0
});




}
/// @nodoc
class _$ImageOperation_OptimizeCopyWithImpl<$Res>
    implements $ImageOperation_OptimizeCopyWith<$Res> {
  _$ImageOperation_OptimizeCopyWithImpl(this._self, this._then);

  final ImageOperation_Optimize _self;
  final $Res Function(ImageOperation_Optimize) _then;

/// Create a copy of ImageOperation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ImageOperation_Optimize(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as OptimizeOptions,
  ));
}


}

/// @nodoc


class ImageOperation_Resize extends ImageOperation {
  const ImageOperation_Resize(this.field0): super._();
  

@override final  ResizeOptions field0;

/// Create a copy of ImageOperation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageOperation_ResizeCopyWith<ImageOperation_Resize> get copyWith => _$ImageOperation_ResizeCopyWithImpl<ImageOperation_Resize>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageOperation_Resize&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ImageOperation.resize(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ImageOperation_ResizeCopyWith<$Res> implements $ImageOperationCopyWith<$Res> {
  factory $ImageOperation_ResizeCopyWith(ImageOperation_Resize value, $Res Function(ImageOperation_Resize) _then) = _$ImageOperation_ResizeCopyWithImpl;
@useResult
$Res call({
 ResizeOptions field0
});




}
/// @nodoc
class _$ImageOperation_ResizeCopyWithImpl<$Res>
    implements $ImageOperation_ResizeCopyWith<$Res> {
  _$ImageOperation_ResizeCopyWithImpl(this._self, this._then);

  final ImageOperation_Resize _self;
  final $Res Function(ImageOperation_Resize) _then;

/// Create a copy of ImageOperation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ImageOperation_Resize(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as ResizeOptions,
  ));
}


}

/// @nodoc


class ImageOperation_Crop extends ImageOperation {
  const ImageOperation_Crop(this.field0): super._();
  

@override final  CropOptions field0;

/// Create a copy of ImageOperation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageOperation_CropCopyWith<ImageOperation_Crop> get copyWith => _$ImageOperation_CropCopyWithImpl<ImageOperation_Crop>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageOperation_Crop&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ImageOperation.crop(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ImageOperation_CropCopyWith<$Res> implements $ImageOperationCopyWith<$Res> {
  factory $ImageOperation_CropCopyWith(ImageOperation_Crop value, $Res Function(ImageOperation_Crop) _then) = _$ImageOperation_CropCopyWithImpl;
@useResult
$Res call({
 CropOptions field0
});




}
/// @nodoc
class _$ImageOperation_CropCopyWithImpl<$Res>
    implements $ImageOperation_CropCopyWith<$Res> {
  _$ImageOperation_CropCopyWithImpl(this._self, this._then);

  final ImageOperation_Crop _self;
  final $Res Function(ImageOperation_Crop) _then;

/// Create a copy of ImageOperation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ImageOperation_Crop(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as CropOptions,
  ));
}


}

/// @nodoc


class ImageOperation_Extend extends ImageOperation {
  const ImageOperation_Extend(this.field0): super._();
  

@override final  ExtendOptions field0;

/// Create a copy of ImageOperation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageOperation_ExtendCopyWith<ImageOperation_Extend> get copyWith => _$ImageOperation_ExtendCopyWithImpl<ImageOperation_Extend>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageOperation_Extend&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ImageOperation.extend(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ImageOperation_ExtendCopyWith<$Res> implements $ImageOperationCopyWith<$Res> {
  factory $ImageOperation_ExtendCopyWith(ImageOperation_Extend value, $Res Function(ImageOperation_Extend) _then) = _$ImageOperation_ExtendCopyWithImpl;
@useResult
$Res call({
 ExtendOptions field0
});




}
/// @nodoc
class _$ImageOperation_ExtendCopyWithImpl<$Res>
    implements $ImageOperation_ExtendCopyWith<$Res> {
  _$ImageOperation_ExtendCopyWithImpl(this._self, this._then);

  final ImageOperation_Extend _self;
  final $Res Function(ImageOperation_Extend) _then;

/// Create a copy of ImageOperation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ImageOperation_Extend(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as ExtendOptions,
  ));
}


}

/// @nodoc
mixin _$ResizeSpec {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResizeSpec);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ResizeSpec()';
}


}

/// @nodoc
class $ResizeSpecCopyWith<$Res>  {
$ResizeSpecCopyWith(ResizeSpec _, $Res Function(ResizeSpec) __);
}


/// Adds pattern-matching-related methods to [ResizeSpec].
extension ResizeSpecPatterns on ResizeSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ResizeSpec_Width value)?  width,TResult Function( ResizeSpec_Height value)?  height,TResult Function( ResizeSpec_Exact value)?  exact,TResult Function( ResizeSpec_Fit value)?  fit,TResult Function( ResizeSpec_Scale value)?  scale,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ResizeSpec_Width() when width != null:
return width(_that);case ResizeSpec_Height() when height != null:
return height(_that);case ResizeSpec_Exact() when exact != null:
return exact(_that);case ResizeSpec_Fit() when fit != null:
return fit(_that);case ResizeSpec_Scale() when scale != null:
return scale(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ResizeSpec_Width value)  width,required TResult Function( ResizeSpec_Height value)  height,required TResult Function( ResizeSpec_Exact value)  exact,required TResult Function( ResizeSpec_Fit value)  fit,required TResult Function( ResizeSpec_Scale value)  scale,}){
final _that = this;
switch (_that) {
case ResizeSpec_Width():
return width(_that);case ResizeSpec_Height():
return height(_that);case ResizeSpec_Exact():
return exact(_that);case ResizeSpec_Fit():
return fit(_that);case ResizeSpec_Scale():
return scale(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ResizeSpec_Width value)?  width,TResult? Function( ResizeSpec_Height value)?  height,TResult? Function( ResizeSpec_Exact value)?  exact,TResult? Function( ResizeSpec_Fit value)?  fit,TResult? Function( ResizeSpec_Scale value)?  scale,}){
final _that = this;
switch (_that) {
case ResizeSpec_Width() when width != null:
return width(_that);case ResizeSpec_Height() when height != null:
return height(_that);case ResizeSpec_Exact() when exact != null:
return exact(_that);case ResizeSpec_Fit() when fit != null:
return fit(_that);case ResizeSpec_Scale() when scale != null:
return scale(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( int value)?  width,TResult Function( int value)?  height,TResult Function( int width,  int height)?  exact,TResult Function( int maxWidth,  int maxHeight)?  fit,TResult Function( double factor)?  scale,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ResizeSpec_Width() when width != null:
return width(_that.value);case ResizeSpec_Height() when height != null:
return height(_that.value);case ResizeSpec_Exact() when exact != null:
return exact(_that.width,_that.height);case ResizeSpec_Fit() when fit != null:
return fit(_that.maxWidth,_that.maxHeight);case ResizeSpec_Scale() when scale != null:
return scale(_that.factor);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( int value)  width,required TResult Function( int value)  height,required TResult Function( int width,  int height)  exact,required TResult Function( int maxWidth,  int maxHeight)  fit,required TResult Function( double factor)  scale,}) {final _that = this;
switch (_that) {
case ResizeSpec_Width():
return width(_that.value);case ResizeSpec_Height():
return height(_that.value);case ResizeSpec_Exact():
return exact(_that.width,_that.height);case ResizeSpec_Fit():
return fit(_that.maxWidth,_that.maxHeight);case ResizeSpec_Scale():
return scale(_that.factor);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( int value)?  width,TResult? Function( int value)?  height,TResult? Function( int width,  int height)?  exact,TResult? Function( int maxWidth,  int maxHeight)?  fit,TResult? Function( double factor)?  scale,}) {final _that = this;
switch (_that) {
case ResizeSpec_Width() when width != null:
return width(_that.value);case ResizeSpec_Height() when height != null:
return height(_that.value);case ResizeSpec_Exact() when exact != null:
return exact(_that.width,_that.height);case ResizeSpec_Fit() when fit != null:
return fit(_that.maxWidth,_that.maxHeight);case ResizeSpec_Scale() when scale != null:
return scale(_that.factor);case _:
  return null;

}
}

}

/// @nodoc


class ResizeSpec_Width extends ResizeSpec {
  const ResizeSpec_Width({required this.value}): super._();
  

 final  int value;

/// Create a copy of ResizeSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResizeSpec_WidthCopyWith<ResizeSpec_Width> get copyWith => _$ResizeSpec_WidthCopyWithImpl<ResizeSpec_Width>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResizeSpec_Width&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'ResizeSpec.width(value: $value)';
}


}

/// @nodoc
abstract mixin class $ResizeSpec_WidthCopyWith<$Res> implements $ResizeSpecCopyWith<$Res> {
  factory $ResizeSpec_WidthCopyWith(ResizeSpec_Width value, $Res Function(ResizeSpec_Width) _then) = _$ResizeSpec_WidthCopyWithImpl;
@useResult
$Res call({
 int value
});




}
/// @nodoc
class _$ResizeSpec_WidthCopyWithImpl<$Res>
    implements $ResizeSpec_WidthCopyWith<$Res> {
  _$ResizeSpec_WidthCopyWithImpl(this._self, this._then);

  final ResizeSpec_Width _self;
  final $Res Function(ResizeSpec_Width) _then;

/// Create a copy of ResizeSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(ResizeSpec_Width(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ResizeSpec_Height extends ResizeSpec {
  const ResizeSpec_Height({required this.value}): super._();
  

 final  int value;

/// Create a copy of ResizeSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResizeSpec_HeightCopyWith<ResizeSpec_Height> get copyWith => _$ResizeSpec_HeightCopyWithImpl<ResizeSpec_Height>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResizeSpec_Height&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode => Object.hash(runtimeType,value);

@override
String toString() {
  return 'ResizeSpec.height(value: $value)';
}


}

/// @nodoc
abstract mixin class $ResizeSpec_HeightCopyWith<$Res> implements $ResizeSpecCopyWith<$Res> {
  factory $ResizeSpec_HeightCopyWith(ResizeSpec_Height value, $Res Function(ResizeSpec_Height) _then) = _$ResizeSpec_HeightCopyWithImpl;
@useResult
$Res call({
 int value
});




}
/// @nodoc
class _$ResizeSpec_HeightCopyWithImpl<$Res>
    implements $ResizeSpec_HeightCopyWith<$Res> {
  _$ResizeSpec_HeightCopyWithImpl(this._self, this._then);

  final ResizeSpec_Height _self;
  final $Res Function(ResizeSpec_Height) _then;

/// Create a copy of ResizeSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? value = null,}) {
  return _then(ResizeSpec_Height(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ResizeSpec_Exact extends ResizeSpec {
  const ResizeSpec_Exact({required this.width, required this.height}): super._();
  

 final  int width;
 final  int height;

/// Create a copy of ResizeSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResizeSpec_ExactCopyWith<ResizeSpec_Exact> get copyWith => _$ResizeSpec_ExactCopyWithImpl<ResizeSpec_Exact>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResizeSpec_Exact&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,width,height);

@override
String toString() {
  return 'ResizeSpec.exact(width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $ResizeSpec_ExactCopyWith<$Res> implements $ResizeSpecCopyWith<$Res> {
  factory $ResizeSpec_ExactCopyWith(ResizeSpec_Exact value, $Res Function(ResizeSpec_Exact) _then) = _$ResizeSpec_ExactCopyWithImpl;
@useResult
$Res call({
 int width, int height
});




}
/// @nodoc
class _$ResizeSpec_ExactCopyWithImpl<$Res>
    implements $ResizeSpec_ExactCopyWith<$Res> {
  _$ResizeSpec_ExactCopyWithImpl(this._self, this._then);

  final ResizeSpec_Exact _self;
  final $Res Function(ResizeSpec_Exact) _then;

/// Create a copy of ResizeSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,}) {
  return _then(ResizeSpec_Exact(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ResizeSpec_Fit extends ResizeSpec {
  const ResizeSpec_Fit({required this.maxWidth, required this.maxHeight}): super._();
  

 final  int maxWidth;
 final  int maxHeight;

/// Create a copy of ResizeSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResizeSpec_FitCopyWith<ResizeSpec_Fit> get copyWith => _$ResizeSpec_FitCopyWithImpl<ResizeSpec_Fit>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResizeSpec_Fit&&(identical(other.maxWidth, maxWidth) || other.maxWidth == maxWidth)&&(identical(other.maxHeight, maxHeight) || other.maxHeight == maxHeight));
}


@override
int get hashCode => Object.hash(runtimeType,maxWidth,maxHeight);

@override
String toString() {
  return 'ResizeSpec.fit(maxWidth: $maxWidth, maxHeight: $maxHeight)';
}


}

/// @nodoc
abstract mixin class $ResizeSpec_FitCopyWith<$Res> implements $ResizeSpecCopyWith<$Res> {
  factory $ResizeSpec_FitCopyWith(ResizeSpec_Fit value, $Res Function(ResizeSpec_Fit) _then) = _$ResizeSpec_FitCopyWithImpl;
@useResult
$Res call({
 int maxWidth, int maxHeight
});




}
/// @nodoc
class _$ResizeSpec_FitCopyWithImpl<$Res>
    implements $ResizeSpec_FitCopyWith<$Res> {
  _$ResizeSpec_FitCopyWithImpl(this._self, this._then);

  final ResizeSpec_Fit _self;
  final $Res Function(ResizeSpec_Fit) _then;

/// Create a copy of ResizeSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? maxWidth = null,Object? maxHeight = null,}) {
  return _then(ResizeSpec_Fit(
maxWidth: null == maxWidth ? _self.maxWidth : maxWidth // ignore: cast_nullable_to_non_nullable
as int,maxHeight: null == maxHeight ? _self.maxHeight : maxHeight // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class ResizeSpec_Scale extends ResizeSpec {
  const ResizeSpec_Scale({required this.factor}): super._();
  

 final  double factor;

/// Create a copy of ResizeSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResizeSpec_ScaleCopyWith<ResizeSpec_Scale> get copyWith => _$ResizeSpec_ScaleCopyWithImpl<ResizeSpec_Scale>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResizeSpec_Scale&&(identical(other.factor, factor) || other.factor == factor));
}


@override
int get hashCode => Object.hash(runtimeType,factor);

@override
String toString() {
  return 'ResizeSpec.scale(factor: $factor)';
}


}

/// @nodoc
abstract mixin class $ResizeSpec_ScaleCopyWith<$Res> implements $ResizeSpecCopyWith<$Res> {
  factory $ResizeSpec_ScaleCopyWith(ResizeSpec_Scale value, $Res Function(ResizeSpec_Scale) _then) = _$ResizeSpec_ScaleCopyWithImpl;
@useResult
$Res call({
 double factor
});




}
/// @nodoc
class _$ResizeSpec_ScaleCopyWithImpl<$Res>
    implements $ResizeSpec_ScaleCopyWith<$Res> {
  _$ResizeSpec_ScaleCopyWithImpl(this._self, this._then);

  final ResizeSpec_Scale _self;
  final $Res Function(ResizeSpec_Scale) _then;

/// Create a copy of ResizeSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? factor = null,}) {
  return _then(ResizeSpec_Scale(
factor: null == factor ? _self.factor : factor // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
