# Conclusiones

## Conclusión por equipo

El proyecto integra LDAP, privacyIDEA, FreeOTP y OwnCloud en un laboratorio académico que cubre las cuatro capas del control de acceso definidas por la asignatura. La aproximación de Docker Compose con scripts idempotentes redujo el costo de reproducción a la mínima expresión: cualquier integrante puede clonar el repositorio, ejecutar siete comandos y obtener un entorno equivalente al de los demás. Esto liberó esfuerzo para concentrarse en lo que realmente exige criterio: el diseño del árbol LDAP, la integración entre los componentes, el cifrado del lado servidor con `master key` y la captura de auditoría.

Lo más valioso del ejercicio fue convertir conceptos teóricos (identificación, autenticación, autorización, auditoría) en piezas concretas y verificables. Cada validación del profesor (i a v) se cierra con un script que la demuestra de forma automática; cada decisión de arquitectura quedó documentada antes de tocarse. Esa disciplina previno retrabajo: cuando hubo que mover OwnCloud a HTTPS por TLS, ya estaba claro qué cambiaba en el árbol LDAP, en el resolver de privacyIDEA y en los certificados.

Las limitaciones aceptadas a propósito son igualmente formativas. Versionar el `.env` con contraseñas en texto plano, usar certificados autofirmados, manejar una sola instancia por servicio y almacenar la llave maestra del cifrado en el mismo servidor donde están los archivos cifrados son malas prácticas conscientes y documentadas. Listarlas explícitamente en el README es un ejercicio de honestidad técnica que preferimos hacer ahora, antes de que alguien clone el repo y lo lleve sin querer a producción.

Si tuviéramos que llevar este proyecto a un entorno real, los siguientes pasos serían: rotar contraseñas y mover el secreto a un gestor (HashiCorp Vault, AWS Secrets Manager, etc.), hashear `userPassword` antes de importar al LDAP, reemplazar la CA local por una pública (Let's Encrypt o una CA corporativa), introducir alta disponibilidad en cada componente, segmentar la red Docker con políticas de firewall internas, sustituir la llave maestra por cifrado extremo a extremo del lado del cliente y redirigir las bitácoras a un SIEM consultable desde un único panel. Todo esto está fuera del alcance del semestre, pero saber dónde están los huecos es parte del aprendizaje.

## Conclusiones individuales

Cada integrante redacta una conclusión propia de aproximadamente 200 palabras. Sugerimos cubrir tres preguntas: qué responsabilidad asumiste, qué aprendiste técnicamente y qué cambiarías si volvieras a hacerlo. Los espacios siguientes son para que cada quien complete el suyo antes de imprimir el PDF.

### Arellanes Conde Esteban

(Pendiente de redacción individual)

### Ferreira Rojas Mauricio

(Pendiente de redacción individual)

### López Segundo Luis Iván

(Pendiente de redacción individual)

### Olvera González Arely

(Pendiente de redacción individual)

### Rufino López María Elena

(Pendiente de redacción individual)

### Salgado Miranda Jorge

(Pendiente de redacción individual)
