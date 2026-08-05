CREATE TABLE IF NOT EXISTS usuarios_app (
    id serial PRIMARY KEY,
    usuario text NOT NULL UNIQUE,
    creado_en timestamp DEFAULT now()
);

INSERT INTO usuarios_app(usuario)
VALUES ('usuario_persistente_demo')
ON CONFLICT (usuario) DO NOTHING;
