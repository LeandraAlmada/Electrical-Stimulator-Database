-- Remover todas as tabelas que têm relações entre si (na ordem inversa de criação)
DROP TABLE IF EXISTS descritor CASCADE;
DROP TABLE IF EXISTS amplitude_personalizada CASCADE;
DROP TABLE IF EXISTS limiar CASCADE;
DROP TABLE IF EXISTS estimulo_limiar CASCADE;
DROP TABLE IF EXISTS voluntario CASCADE;
DROP TABLE IF EXISTS resposta_3 CASCADE;

-- Remover os tipos ENUM que foram criados
DROP TYPE IF EXISTS mao_dominante_enum CASCADE;
DROP TYPE IF EXISTS sexo_enum CASCADE;
DROP TYPE IF EXISTS tipo_limiar_enum CASCADE;
DROP TYPE IF EXISTS bloco_enum CASCADE;
DROP TYPE IF EXISTS resposta_2_enum CASCADE;
DROP TYPE IF EXISTS personal_amplitude_enum CASCADE;

-------------------------------------------------------------------------------------------------------


--PARA LIMITAR A ENTRADA EM ALGUNS ATRIBUTOS QUE DEVEM TER VALORES CONSTANTES ENTRE AS TUPLAS
CREATE TYPE mao_dominante_enum AS ENUM ('Direita', 'Esquerda', 'Ambidestro');

CREATE TYPE sexo_enum AS ENUM ('Feminino', 'Masculino', 'Outro');

CREATE TYPE tipo_limiar_enum AS ENUM ('Sensaçao', 'Dor');

CREATE TYPE bloco_enum AS ENUM ('Crescente', 'Decrescente');

CREATE TYPE personal_amplitude_enum AS ENUM ('50', '80', 'media');

----CRIAÇÃO TABELAS----
CREATE TABLE voluntario (
    id_voluntario INT PRIMARY KEY,
    mao_dominante mao_dominante_enum NOT NULL, 
    nome VARCHAR(100) NOT NULL,
    sobrenome VARCHAR(100) NOT NULL,
    idade INT NOT NULL,
    sexo sexo_enum NOT NULL
);

CREATE TABLE estimulo_limiar (
    id_est_limiar INT PRIMARY KEY,
    frequencia FLOAT NOT NULL,
    largura_pulso FLOAT NOT NULL
);

CREATE TABLE limiar (
    id_limiar INT PRIMARY KEY,
    id_voluntario INT,
    id_est_limiar INT,
    amplitude_mA FLOAT NOT NULL,
    repeticao INT NOT NULL,
    tipo_limiar tipo_limiar_enum NOT NULL,
    FOREIGN KEY (id_voluntario) REFERENCES voluntario(id_voluntario),
    FOREIGN KEY (id_est_limiar) REFERENCES estimulo_limiar(id_est_limiar)
);


--PREENCHIDA COM STORED PROCEDURE
CREATE TABLE amplitude_personalizada (
    id_amplitude INT PRIMARY KEY,
    id_voluntario INT,
    media_tri_sensacao FLOAT,
    media_tri_dor FLOAT,
    sensacao_50 FLOAT,
    dor_80 FLOAT,
    media_50_80 FLOAT,
    FOREIGN KEY (id_voluntario) REFERENCES voluntario(id_voluntario)
);

-- Qual foi a intensidade da sensação numa escala de 0 a 10?--- só um INT resolve
-- A sensação pareceu mais discreta ou contínua?---
CREATE TYPE resposta_2_enum AS ENUM ('SIM', 'NÃO', 'NÃO SEI');
-- Houve alguma alteração na frequência do ultimo estimulo em relação ao anterior?---
CREATE TABLE resposta_3 (
    id_resposta_3 INT PRIMARY KEY,
    escolha VARCHAR(100) NOT NULL
);

CREATE TABLE descritor (
    id_descritor INT PRIMARY KEY,
    id_voluntario INT,
    id_amplitude INT,
    tipo_amplitude personal_amplitude_enum NOT null,
    bloco bloco_enum NOT NULL,
    frequencia FLOAT NOT NULL,
    repeticao INT NOT NULL,
    resposta_1 INT NOT NULL,
    resposta_2 resposta_2_enum NOT NULL,
    id_resposta_3 INT,
    FOREIGN KEY (id_voluntario) REFERENCES voluntario(id_voluntario),
    FOREIGN KEY (id_amplitude) REFERENCES amplitude_personalizada(id_amplitude),
    FOREIGN KEY (id_resposta_3) REFERENCES resposta_3(id_resposta_3)
);

------ POPULANDO O BANCO DE DADOS -------
-- Inserindo dados na tabela voluntario
INSERT INTO voluntario (id_voluntario, mao_dominante, nome, sobrenome, idade, sexo) VALUES
(1, 'Direita', 'Ana', 'Silva', 25, 'Feminino'),
(2, 'Esquerda', 'Carlos', 'Santos', 30, 'Masculino'),
(3, 'Ambidestro', 'Mariana', 'Oliveira', 22, 'Feminino');

-- Inserindo dados na tabela estimulo_limiar
INSERT INTO estimulo_limiar (id_est_limiar, frequencia, largura_pulso) VALUES
(1, 10, 0.1), --sensação
(2, 125, 0.1); --dor

-- Inserindo dados na tabela limiar em triplicata para cada voluntário
INSERT INTO limiar (id_limiar, id_voluntario, id_est_limiar, amplitude_mA, repeticao, tipo_limiar) VALUES
-- Voluntário 1 com Estímulo 1, Limiar de Sensaçao
(1, 1, 1, 1.2, 1, 'Sensaçao'),
(2, 1, 1, 1.3, 2, 'Sensaçao'),
(3, 1, 1, 1.1, 3, 'Sensaçao'),
-- Voluntário 1 com Estímulo 2, Limiar de Dor
(4, 1, 2, 2.5, 1, 'Dor'),
(5, 1, 2, 2.6, 2, 'Dor'),
(6, 1, 2, 2.4, 3, 'Dor'),

-- Voluntário 2 com Estímulo 2, Limiar de Sensaçao
(7, 2, 1, 1.5, 1, 'Sensaçao'),
(8, 2, 1, 1.6, 2, 'Sensaçao'),
(9, 2, 1, 1.4, 3, 'Sensaçao'),
-- Voluntário 2 com Estímulo 2, Limiar de Dor
(10, 2, 2, 3.0, 1, 'Dor'),
(11, 2, 2, 3.1, 2, 'Dor'),
(12, 2, 2, 2.9, 3, 'Dor'),

-- Voluntário 3 com Estímulo 3, Limiar de Sensaçao
(13, 3, 1, 1.8, 1, 'Sensaçao'),
(14, 3, 1, 1.7, 2, 'Sensaçao'),
(15, 3, 1, 1.9, 3, 'Sensaçao'),
-- Voluntário 3 com Estímulo 3, Limiar de Dor
(16, 3, 2, 2.8, 1, 'Dor'),
(17, 3, 2, 2.9, 2, 'Dor'),
(18, 3, 2, 2.7, 3, 'Dor');


INSERT INTO resposta_3 (id_resposta_3, escolha) VALUES
(1, 'Aumentou'),
(2, 'Diminuiu'),
(3, 'Igual');


--Função para preencher a tabela Amplitude_personalizada
CREATE OR REPLACE FUNCTION preencher_amplitude_personalizada()
RETURNS VOID AS $$
DECLARE
    voluntario_id INT;
    est_limiar_id INT;
    media_sensacao FLOAT;
    media_dor FLOAT;
    valor_50_sensacao FLOAT;
    valor_80_dor FLOAT;
    media_50_80 FLOAT;
    novo_id_amplitude INT;
BEGIN
    -- Loop para cada voluntário e estímulo único na tabela `limiar`
    FOR voluntario_id, est_limiar_id IN
        SELECT DISTINCT id_voluntario
        FROM limiar
    LOOP
        -- Calculando a média da triplicata para o limiar de sensação
        SELECT AVG(amplitude_mA) INTO media_sensacao 
        FROM limiar 
        WHERE id_voluntario = voluntario_id  
        AND tipo_limiar = 'Sensaçao';

        -- Calculando a média da triplicata para o limiar de dor
        SELECT AVG(amplitude_mA) INTO media_dor 
        FROM limiar 
        WHERE id_voluntario = voluntario_id 
        AND tipo_limiar = 'Dor';

        -- Calculando os valores finais
        valor_50_sensacao := media_sensacao * 0.5;
        valor_80_dor := media_dor * 0.8;
        media_50_80 := (valor_50_sensacao + valor_80_dor) / 2;

        -- Gerando um novo id_amplitude único
        SELECT COALESCE(MAX(id_amplitude), 0) + 1 INTO novo_id_amplitude FROM amplitude_personalizada;

        -- Inserindo os valores na tabela amplitude_personalizada, incluindo as médias das triplicatas
        INSERT INTO amplitude_personalizada (
            id_amplitude,
            id_voluntario, 
            media_tri_sensacao, 
            media_tri_dor, 
            sensacao_50, 
            dor_80, 
            media_50_80
        ) VALUES (
            novo_id_amplitude,
            voluntario_id, 
            media_sensacao, 
            media_dor, 
            valor_50_sensacao, 
            valor_80_dor, 
            media_50_80
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;


SELECT preencher_amplitude_personalizada();

select * from amplitude_personalizada; 

-- Inserindo dados na tabela descritor
INSERT INTO descritor (id_descritor, id_voluntario, id_amplitude, tipo_amplitude, bloco, frequencia, repeticao, resposta_1, resposta_2, id_resposta_3)
VALUES
-- Usando os valores da coluna sensacao_50
(1, 1, 1, '50', 'Crescente', 10, 1, 5, 'SIM', 1),
(2, 1, 1, '50', 'Crescente', 15, 2, 6, 'NÃO', 2),
(3, 1, 1, '50', 'Crescente', 20, 3, 7, 'NÃO SEI', 3),

(4, 1, 1, '80', 'Decrescente', 25, 1, 5, 'SIM', 1),
(5, 1, 1, '80', 'Decrescente', 30, 2, 6, 'NÃO', 2),
(6, 1, 1, '80', 'Decrescente', 35, 3, 7, 'NÃO SEI', 3),

(7, 1, 1, 'media', 'Crescente', 40, 1, 5, 'SIM', 1),
(8, 1, 1, 'media', 'Crescente', 45, 2, 6, 'NÃO', 2),
(9, 1, 1, 'media', 'Crescente', 50, 3, 7, 'NÃO SEI', 3),

-- Repetindo para o Voluntário 2
(10, 2, 2, '50', 'Crescente', 10, 1, 5, 'SIM', 1),
(11, 2, 2, '50', 'Crescente', 15, 2, 6, 'NÃO', 2),
(12, 2, 2, '50', 'Crescente', 20, 3, 7, 'NÃO SEI', 3),

(13, 2, 2, '80', 'Decrescente', 25, 1, 5, 'SIM', 1),
(14, 2, 2, '80', 'Decrescente', 30, 2, 6, 'NÃO', 2),
(15, 2, 2, '80', 'Decrescente', 35, 3, 7, 'NÃO SEI', 3),

(16, 2, 2, 'media', 'Crescente', 40, 1, 5, 'SIM', 1),
(17, 2, 2, 'media', 'Crescente', 45, 2, 6, 'NÃO', 2),
(18, 2, 2, 'media', 'Crescente', 50, 3, 7, 'NÃO SEI', 3),

-- Repetindo para o Voluntário 3
(19, 3, 3, '50', 'Crescente', 10, 1, 5, 'SIM', 1),
(20, 3, 3, '50', 'Crescente', 15, 2, 6, 'NÃO', 2),
(21, 3, 3, '50', 'Crescente', 20, 3, 7, 'NÃO SEI', 3),

(22, 3, 3, '80', 'Decrescente', 25, 1, 5, 'SIM', 1),
(23, 3, 3, '80', 'Decrescente', 30, 2, 6, 'NÃO', 2),
(24, 3, 3, '80', 'Decrescente', 35, 3, 7, 'NÃO SEI', 3),

(25, 3, 3, 'media', 'Crescente', 40, 1, 5, 'SIM', 1),
(26, 3, 3, 'media', 'Crescente', 45, 2, 6, 'NÃO', 2),
(27, 3, 3, 'media', 'Crescente', 50, 3, 7, 'NÃO SEI', 3);

select * from descritor;

--criando a view para observar dados do voluntario juntamente com as médias das triplicatas
CREATE VIEW vw_voluntarios_amplitude AS
SELECT v.nome, v.sobrenome, v.idade, a.media_tri_sensacao, a.media_tri_dor
FROM voluntario v
JOIN amplitude_personalizada a ON v.id_voluntario = a.id_voluntario;
--consultando-a
SELECT * FROM vw_voluntarios_amplitude;

--criando um trigger
CREATE OR REPLACE FUNCTION deletar_registros_voluntario()
RETURNS TRIGGER AS $$
BEGIN
    -- Deletar registros na tabela limiar
    DELETE FROM limiar WHERE id_voluntario = OLD.id_voluntario;

    -- Deletar registros na tabela amplitude_personalizada
    DELETE FROM amplitude_personalizada WHERE id_voluntario = OLD.id_voluntario;

    -- Deletar registros na tabela descritor
    DELETE FROM descritor WHERE id_amplitude IN (SELECT id_amplitude FROM amplitude_personalizada WHERE id_voluntario = OLD.id_voluntario);

    -- A tabela resposta_3 não tem relacionamento direto, mas você pode adicionar outra lógica aqui se necessário

    RETURN OLD; -- Retorna o registro excluído
END;
$$ LANGUAGE plpgsql;

drop trigger if exists trigger_deletar_voluntario on voluntario

-- Trigger que chama a função ao deletar um voluntário
CREATE TRIGGER trigger_deletar_voluntario
AFTER DELETE ON voluntario
FOR EACH ROW
EXECUTE FUNCTION deletar_registros_voluntario();


DELETE FROM voluntario WHERE id_voluntario = 3;



--AJUSTES NAS CHAVES PARA O DELETE EM CASCATA FUNCIONAR
-- Verifique a definição da chave estrangeira
SELECT
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    a.attname AS column_name,
    confrelid::regclass AS foreign_table_name,
    af.attname AS foreign_column_name
FROM
    pg_constraint AS c
JOIN
    pg_attribute AS a ON a.attnum = ANY(c.conkey) AND a.attrelid = c.conrelid
JOIN
    pg_attribute AS af ON af.attnum = ANY(c.confkey) AND af.attrelid = c.confrelid
WHERE
    contype = 'f'
    AND confrelid::regclass::text = 'voluntario';  -- Filtra apenas para chaves estrangeiras que referenciam voluntario

-- Primeiro, remova a restrição existente
ALTER TABLE limiar
DROP CONSTRAINT limiar_id_voluntario_fkey;

-- Em seguida, adicione a restrição com ON DELETE CASCADE
ALTER TABLE limiar
ADD CONSTRAINT limiar_id_voluntario_fkey
FOREIGN KEY (id_voluntario)
REFERENCES voluntario (id_voluntario)
ON DELETE CASCADE;

-- Primeiro, remova a restrição existente
ALTER TABLE amplitude_personalizada 
DROP CONSTRAINT amplitude_personalizada_id_voluntario_fkey;

-- Em seguida, adicione a restrição com ON DELETE CASCADE
ALTER TABLE amplitude_personalizada
ADD CONSTRAINT amplitude_personalizada_id_voluntario_fkey
FOREIGN KEY (id_voluntario)
REFERENCES voluntario (id_voluntario)
ON DELETE CASCADE;


ALTER TABLE descritor 
DROP CONSTRAINT descritor_id_voluntario_fkey;

-- Em seguida, adicione a restrição com ON DELETE CASCADE
ALTER TABLE descritor
ADD CONSTRAINT descritor_id_voluntario_fkey
FOREIGN KEY (id_voluntario)
REFERENCES voluntario (id_voluntario)
ON DELETE CASCADE;


-- Primeiro, remova a restrição existente
ALTER TABLE descritor
DROP CONSTRAINT descritor_id_amplitude_fkey;

-- Em seguida, adicione a restrição com ON DELETE CASCADE
ALTER TABLE descritor
ADD CONSTRAINT descritor_id_amplitude_fkey
FOREIGN KEY (id_amplitude)  -- Altere para o nome da coluna correta se necessário
REFERENCES amplitude_personalizada (id_amplitude)  -- Altere para o nome correto da coluna
ON DELETE CASCADE;


