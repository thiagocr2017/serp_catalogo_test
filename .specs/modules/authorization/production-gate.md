# Puerta obligatoria de Autenticación antes de producción

La aplicación trabaja localmente sin usuarios autenticados durante el
desarrollo. Por decisión aprobada, `anon` y `authenticated` pueden ejecutar un
conjunto mínimo de RPC de negocio y el primer equipo puede reclamar la
instalación mediante `claim_local_superadmin`.

Este modelo es **provisional y no está autorizado para producción**.

Antes de distribuir una versión de producción, el módulo de Autenticación debe:

1. eliminar `claim_local_superadmin` y revocar su ejecución;
2. migrar el superadministrador provisional a un usuario autenticado;
3. retirar permisos de comandos al rol `anon`;
4. conceder cada RPC a roles autenticados según permisos funcionales;
5. reemplazar actor y autorización basados en dispositivo por `auth.uid()`;
6. conservar nombre e identificador del equipo únicamente como trazabilidad;
7. sustituir las políticas locales de Storage por políticas de usuario/rol;
8. ejecutar pruebas negativas con `anon`, usuarios sin permiso y usuarios de
   otra empresa;
9. impedir el cambio a modo `PRODUCTION` mientras esta puerta no esté cumplida.

Las migraciones de desarrollo que crean permisos provisionales deben incluir
pruebas exactas de alcance para evitar que los permisos se amplíen por accidente.
