class ColaReproduccion {
  final int? id;
  final int idCancion;
  final int posicion;
  final int fechaAgregado;

  ColaReproduccion({
    this.id,
    required this.idCancion,
    required this.posicion,
    required this.fechaAgregado,
  });

  factory ColaReproduccion.fromMap(Map<String, dynamic> map) {
    return ColaReproduccion(
      id: map['id'],
      idCancion: map['id_cancion'],
      posicion: map['posicion'],
      fechaAgregado: map['fecha_agregado'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_cancion': idCancion,
      'posicion': posicion,
      'fecha_agregado': fechaAgregado,
    };
  }
}