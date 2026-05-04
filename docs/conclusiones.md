# Conclusiones

## Conclusión por equipo

El proyecto integra LDAP, privacyIDEA, FreeOTP y OwnCloud en un laboratorio académico que cubre las tres capas evaluables del control de acceso (identificación, autenticación y autorización) y deja documentada la cuarta (auditoría) como complemento, según el alcance que el profesor confirmó por correo. La aproximación de Docker Compose con scripts idempotentes redujo el costo de reproducción a la mínima expresión: cualquier integrante puede clonar el repositorio, ejecutar siete comandos y obtener un entorno equivalente al de los demás. Esto liberó esfuerzo para concentrarse en lo que realmente exige criterio: el diseño del árbol LDAP, la integración entre los componentes, el cifrado del lado servidor con `master key` y la separación clara entre lo que autentica LDAP y lo que autoriza OwnCloud.

Lo más valioso del ejercicio fue convertir conceptos teóricos (identificación, autenticación, autorización, auditoría) en piezas concretas y verificables. Cada validación del profesor (i a v) se cierra con un script que la demuestra de forma automática; cada decisión de arquitectura quedó documentada antes de tocarse. Esa disciplina previno retrabajo: cuando hubo que mover OwnCloud a HTTPS por TLS, ya estaba claro qué cambiaba en el árbol LDAP, en el resolver de privacyIDEA y en los certificados.

Las limitaciones aceptadas a propósito son igualmente formativas. Versionar el `.env` con contraseñas en texto plano, usar certificados autofirmados, manejar una sola instancia por servicio y almacenar la llave maestra del cifrado en el mismo servidor donde están los archivos cifrados son malas prácticas conscientes y documentadas. Listarlas explícitamente en el README es un ejercicio de honestidad técnica que preferimos hacer ahora, antes de que alguien clone el repo y lo lleve sin querer a producción.

Si tuviéramos que llevar este proyecto a un entorno real, los siguientes pasos serían: rotar contraseñas y mover el secreto a un gestor (HashiCorp Vault, AWS Secrets Manager, etc.), hashear `userPassword` antes de importar al LDAP, reemplazar la CA local por una pública (Let's Encrypt o una CA corporativa), introducir alta disponibilidad en cada componente, segmentar la red Docker con políticas de firewall internas, sustituir la llave maestra por cifrado extremo a extremo del lado del cliente y redirigir las bitácoras a un SIEM consultable desde un único panel. Todo esto está fuera del alcance del semestre, pero saber dónde están los huecos es parte del aprendizaje.

## Conclusiones individuales

Cada integrante asumió una parte del proyecto y reflexiona sobre lo que aprendió. Las conclusiones que siguen son una primera redacción que cada quien puede afinar antes de imprimir el PDF; mantener el formato (tres bloques: responsabilidad, aprendizaje, qué cambiaría) ayuda a que la lectura del entregable sea homogénea.

### Arellanes Conde Esteban

Mi rol en este proyecto fue cerrar el bucle entre todo lo que diseñamos y lo que el evaluador puede ver. Cuando el equipo terminó de configurar LDAP, privacyIDEA y OwnCloud, me tocó verificar que las piezas hablaban entre sí correctamente y que el flujo end-to-end funcionaba. Trabajé directamente con `owncloud-login-verify.sh` y `owncloud-share-verify.sh` haciendo de validador: subir un archivo, compartirlo y asegurar que el destinatario pudiera leerlo descifrado.

Lo que aprendí con más fuerza es que las APIs REST con autenticación de doble factor tienen sutilezas que no aparecen en la documentación. Por ejemplo, descubrir que la OCS Sharing API rechaza Basic Auth cuando el usuario tiene 2FA habilitado pero acepta cookies de sesión web. Eso me llevó a entender mejor la diferencia entre autenticación de cliente automatizado y autenticación interactiva, una distinción que en clase parecía teórica.

Si volviera a hacerlo, dedicaría más tiempo a probar escenarios de error desde el principio: contraseñas inválidas, OTPs expirados, tokens reutilizados dentro de la misma ventana de 30 segundos. Esos escenarios son donde se rompen los sistemas reales y son los que más enseñan sobre el comportamiento del software cuando deja de andar el camino feliz.

### Ferreira Rojas Mauricio

Me encargué del bloque de OTP y del enrolamiento con FreeOTP. Antes del proyecto pensaba que TOTP era simplemente un código de seis dígitos; ahora entiendo el detalle: es HMAC-SHA1 sobre el contador de tiempo dividido en ventanas de 30 segundos, con un truncado dinámico que toma cuatro bytes según el offset del último byte del hash. Esa fórmula la implementé en Python para validar localmente sin depender de un teléfono y comprobar que daba el mismo número que privacyIDEA aceptaba en `/validate/check`.

Lo más interesante técnicamente fue entender cómo privacyIDEA usa el concepto de resolver: nunca duplica usuarios, los lee del LDAP por LDAPS y mapea cada UID a su token. Esto significa que dar de baja a un usuario en LDAP lo revoca automáticamente del sistema OTP, sin pasos adicionales. Es un patrón limpio de fuente única de verdad que pocas veces se ve aplicado bien.

Si volviera a hacerlo, exploraría retos más avanzados que TOTP: reto-respuesta, push notifications con confirmación en el teléfono, WebAuthn con llaves físicas. privacyIDEA soporta todos esos métodos pero quedaron fuera del alcance del semestre. También me hubiera gustado documentar el procedimiento de rotación de tokens cuando un usuario pierde su teléfono, que es un caso real frecuente y no trivial.

### López Segundo Luis Iván

Mi parte fue diseñar el árbol LDAP y dejarlo coherente con lo que esperan OwnCloud y privacyIDEA. Antes de tocar configuración revisé varias veces qué campos pide cada aplicación en su pantalla de cliente LDAP, porque eso determina cómo se nombran las OUs, qué `objectClass` reciben los usuarios y dónde vive la cuenta de servicio. La decisión que más me costó fue separar la cuenta `svc-owncloud` del árbol de usuarios humanos y usarla con `objectClass: simpleSecurityObject` y `organizationalRole`, lo que permite que haga bind sin caer en el filtro `(objectClass=inetOrgPerson)`.

Cuando `ldap-verify.sh` empezó a contar exactamente seis humanos sin contaminarse con la cuenta de servicio, supe que la decisión era correcta. También aprendí a escribir ACLs específicas: la cuenta de servicio puede leer atributos de los usuarios pero no `userPassword`. Esto es de manual, pero verlo funcionar en `slapd` con archivos LDIF importados al primer arranque tiene otro peso.

Si volviera a hacerlo, empezaría por dibujar el árbol completo en una hoja antes de tocar el primer LDIF. Hicimos varias iteraciones (dónde colocar `ou=Servicios`, si separar `ou=Usuarios` o no, qué hacer con `ou=Grupos`) que se hubieran ahorrado con un boceto más reflexivo desde el inicio.

### Olvera González Arely

Me asignaron el bloque de marco conceptual de la presentación: explicar por qué 2FA, los tres factores de autenticación y la diferencia entre HOTP y TOTP. Para hacerlo bien tuve que leer las RFCs originales (4226 y 6238) y cotejar lo que decían con lo que efectivamente hace privacyIDEA en su API. No es lo mismo decir TOTP que vivirlo: ver que el contador es `unix_time / 30` y que el HMAC-SHA1 produce el mismo código en el teléfono y en el servidor solo si los dos relojes están sincronizados.

Lo más útil del proyecto fue conectar la teoría con piezas tangibles. Cuando vi en los logs de privacyIDEA el mensaje `wrong otp value. previous otp used again` me quedó claro por qué los tokens no se reutilizan dentro de una misma ventana de 30 segundos: es la protección anti-replay que el estándar exige y que evita ataques de repetición triviales.

Si tuviera más tiempo, haría una comparación entre HOTP, TOTP y los métodos basados en push (notificaciones empujadas al teléfono). El proyecto se enfocó en TOTP porque era lo que pedía el anexo, pero hay un mundo de mejoras de usabilidad que TOTP no resuelve y que vale la pena conocer para escoger bien la siguiente vez.

### Rufino López María Elena

Yo me encargué de OwnCloud y de articular su integración con LDAP y privacyIDEA. Lo primero que aprendí es que OwnCloud no implementa 2FA por sí solo: tiene un sistema de plugins y `twofactor_privacyidea` es uno oficial que delega completamente la validación del segundo factor al servidor de tokens. Esa separación de responsabilidades me pareció elegante y responde al principio de no rehacer en cada aplicación lo que ya existe en una pieza especializada.

La parte que me dio más trabajo fue activar Server Side Encryption con master key y verificar que efectivamente los archivos quedan cifrados en disco. Aprendí a leer la cabecera `HBEGIN:oc_encryption_module:OC_DEFAULT_MODULE:cipher:AES-256-CTR:HEND` y a entender que esa es la prueba concreta de que el cifrado está activo. También entendí su limitación: la llave maestra vive en el mismo servidor, así que protege contra robo de disco pero no contra el administrador del servidor.

También trabajé con la app `user_ldap` configurándola con `occ ldap:set-config`. Lo que parecía un wizard gráfico es realmente una serie de claves de configuración, cada una con su valor, y verlo desde la línea de comandos me ayudó a entender mejor qué hace cada campo. Si volviera a hacerlo, exploraría OCIS (la versión nueva de OwnCloud reescrita en Go) en lugar de OwnCloud 10. Para fines de este proyecto, OwnCloud 10 fue la opción más madura y mejor documentada.

### Salgado Miranda Jorge

Como propietario del repositorio y coordinador del proyecto, mi responsabilidad fue mantener la coherencia del laboratorio en su conjunto: que cada decisión local respondiera a un objetivo global, que las piezas hablaran entre sí y que cualquier integrante (o el evaluador) pudiera reproducir el entorno desde cero en menos de 10 minutos. Esto significó pensar mucho antes de tocar código y construir las herramientas de validación antes que las de configuración.

Adopté de forma deliberada una práctica que en el equipo llamamos *infraestructura como verificación*: para cada componente que añadimos al stack, primero escribimos el `*-verify.sh` que demuestra que funciona y solo después el `*-configure.sh` que lo deja en ese estado deseado. El orden no es trivial. Cuando el verificador existe antes que el configurador, no hay forma de mentirse a uno mismo sobre si el sistema funciona, porque el verificador exige que el sistema responda en producción tal como esperabas en diseño. Esa disciplina fue la que más impactó la calidad del entregable: las cinco validaciones del profesor (i a v) no son afirmaciones, son scripts ejecutables que cualquiera puede correr.

Diseñé también el flujo de auditoría reproducible (`scripts/audit-capture.sh`), que dispara los ocho eventos clave del control de acceso (login LDAP exitoso y fallido, enrolamiento, OTP correcto y rechazado, login web 2FA exitoso y rechazado, acceso a archivo por WebDAV) y captura las líneas relevantes de los logs de OpenLDAP, privacyIDEA y OwnCloud filtrando por usuario y por marca de tiempo. Antes lo hacía a mano cada vez que quería evidencia para una sección de la memoria; convertirlo en script lo volvió un activo del proyecto que sirve para la presentación, para la documentación y para enseñar dónde mirar en cada componente cuando algo se rompe.

Lo que más aprendí fue el valor de documentar las limitaciones explícitamente. La sección "Aviso de seguridad" del README enumera ocho prácticas que serían inaceptables en un entorno real: versionar `.env` con contraseñas en texto plano, usar contraseñas compartidas, dejar `userPassword` plano en los LDIFs, usar certificados autofirmados, no tener alta disponibilidad, no aplicar segmentación de red, no implementar lockout y dejar la llave maestra en el mismo servidor que los archivos cifrados. Todas las aceptamos a propósito por contexto académico y todas están documentadas. Ese ejercicio de honestidad técnica, donde pones por escrito qué hiciste mal a sabiendas y por qué, es lo más útil que me llevo del semestre y la práctica que más quiero conservar en proyectos futuros.

Si volviera a empezar, invertiría más tiempo desde el día uno en automatizar las verificaciones con CI/CD: un GitHub Action que corriera `shellcheck`, `docker compose config` y la búsqueda de caracteres prohibidos en cada push hubiera evitado las correcciones manuales que hicimos al final. El proyecto está cerrado y reproducible, pero se sostiene por disciplina humana en lugar de automatización; en un entorno laboral eso no escalaría. También invertiría tiempo en una capa de tests unitarios para los scripts críticos: hoy probamos cada script ejecutándolo, lo que es lento y no nos dice qué falla cuando falla. Y finalmente, hubiera arrancado con un diseño explícito del modelo de amenazas: enumerar atacantes, vectores y mitigaciones antes de configurar cada componente. Lo hicimos al revés (primero implementamos, después documentamos) y aunque funcionó, en un proyecto más grande ese orden inverso cuesta caro.

Pese a las limitaciones aceptadas, el resultado me deja contento: un laboratorio que cubre las tres capas evaluables del control de acceso (identificación, autenticación y autorización), que mantiene la cuarta como complemento académico documentado, que se levanta con seis comandos, que se valida con scripts y que documenta tanto sus fortalezas como sus huecos. Es exactamente lo que esperaría que aprendiera un estudiante de Seguridad Informática Avanzada al cierre del semestre.
