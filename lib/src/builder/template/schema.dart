import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'package:corona/src/builder/template/helpers/naming.dart' as naming;
import 'package:corona/src/builder/template/helpers/tokens.dart' as tokens;

class SchemaDecoder<S extends ClassElement, T extends String> extends Converter<S, T> {
  const SchemaDecoder();

  @override
  T convert(S input) {
    final StringBuffer buffer = new StringBuffer();
    final Set<PropertyAccessorElement> accessors = new Set<PropertyAccessorElement>.from(input.accessors);

    input.allSupertypes.forEach((InterfaceType type) {
      if (!type.isDartCoreObject) accessors.addAll(type.accessors);
    });

    input.interfaces.forEach((InterfaceType type) {
      accessors.addAll(type.accessors);
    });

    input.mixins.forEach((InterfaceType type) {
      accessors.addAll(type.accessors);
    });

    buffer.write(tokens.decl.forClass);
    buffer.write(tokens.space);
    buffer.write(naming.getSchemaName(input.displayName));
    buffer.write(tokens.typeOpen);
    buffer.write('T');
    buffer.write(tokens.typeClose);
    buffer.write(tokens.space);
    buffer.write(tokens.decl.forExtends);
    buffer.write(tokens.space);
    buffer.write('ObjectSchema');
    buffer.write(tokens.typeOpen);
    buffer.write('T');
    buffer.write(tokens.typeClose);

    buffer.write(tokens.bracketsOpen);

    buffer.write('const ${naming.getSchemaName(input.displayName)}(List<String> path\$) : super(path\$);');

    accessors.forEach((PropertyAccessorElement accessor) {
      if (accessor.isGetter) {
        String name;
        String genType = accessor.returnType.displayName;

        if (accessor.returnType.element.kind.ordinal > 0) {

          /*if (accessor.returnType.element.enclosingElement.library.displayName == input.library.displayName) {
            name = naming.getSchemaName(accessor.returnType.element.enclosingElement.displayName);
          } else {*/
            name = 'ObjectSchema';
          /*}*/

          genType = 'dynamic';
        } else if (accessor.returnType.element.library.displayName == input.library.displayName) {
          name = naming.getSchemaName(accessor.returnType.element.displayName);
        } else {
          name = 'ObjectSchema';
        }

        buffer.write(name);
        buffer.write(tokens.typeOpen);
        buffer.write(genType);
        buffer.write(tokens.typeClose);
        buffer.write(tokens.space);
        buffer.write(tokens.getter);
        buffer.write(tokens.space);
        buffer.write(accessor.displayName);
        buffer.write(tokens.fatArrow);
        buffer.write(tokens.ctrNew);
        buffer.write(tokens.space);
        buffer.write(name);
        buffer.write(tokens.typeOpen);
        buffer.write(genType);
        buffer.write(tokens.typeClose);
        buffer.write(tokens.argsOpen);
        buffer.write('''path\$ != null ? (List<String>.from(path\$)..add('${accessor.displayName}')) : const ['${accessor.displayName}']''');
        buffer.write(tokens.argsClose);
        buffer.write(tokens.closeLine);
      }
    });

    buffer.write(tokens.bracketsClose);

    buffer.write('''
    ${input.displayName} ${naming.getLensName(input.displayName)}<S>
      (${input.displayName} entity, ObjectSchema<S> path(${naming.getSchemaName(input.displayName)}<${input.displayName}> schema), S swapper(S oldValue)) {
    final schema = path(const ${naming.getSchemaName(input.displayName)}<${input.displayName}>(null));
    final values = <dynamic>[entity];
    final tearOffs = <dynamic>[${naming.getCtrTearOffName(input.displayName)}];
    dynamic newValue;
  
    for (var i=0, len=schema.path\$.length; i<len; i++) {
      var key = schema.path\$[i];
      var currValue = values.last as TearOffAndValueObjectSchema;
  
      if (i < len-1) {
        tearOffs.add(currValue.getTearOffForKey(key));
        values.add(currValue.getValueFromKey(key));
      } else {
        newValue = swapper(currValue.getValueFromKey(key) as S);
      }
    }
    
    for (var i=tearOffs.length-1; i>=0; i--) {
      newValue = tearOffs[i](
          values[i], schema.path\$[i], newValue);
    }
  
    return newValue as ${input.displayName};
    } ''');

    return buffer.toString();
  }

  String _getDisplayNameWithGenericTypes(ClassElement input) {
    final StringBuffer buffer = new StringBuffer();

    buffer.write(naming.getImplClassName(input.displayName));

    if (_hasGenericTypes(input)) {
      buffer.write(tokens.typeOpen);
      buffer.write(_getGenericTypeDecl(input).map((_GenericTypeDecl decl) => decl.ext).join(', '));
      buffer.write(tokens.typeClose);
    }

    return buffer.toString();
  }

  bool _hasGenericTypes(S input) => input.thisType.element.typeParameters.isNotEmpty;

  Iterable<_GenericTypeDecl> _getGenericTypeDecl(S input) {
    final List<_GenericTypeDecl> list = <_GenericTypeDecl>[];

    input.thisType.element.typeParameters.forEach((TypeParameterElement t) {
      list.add(new _GenericTypeDecl(t.displayName, t.bound.displayName));
    });

    return list;
  }
}

class _GenericTypeDecl {
  final String name, ext;

  _GenericTypeDecl(this.name, this.ext);

  String toString() => '$name extends $ext';
}