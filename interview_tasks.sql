--Таблица для хранения информации пользователей.
--Чтобы было возможно показывать информацию о количестве лайков, не пересчитывая их каждый раз по таблице лайков, 
--что создало бы значительную нагрузку на нее, в эту таблицу добавлены столбцы, содержащие агрегирующие значения для лайков.

CREATE TABLE `social_network`.`user` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(255) NOT NULL,
  `likes_received` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'количество полученных лайков',
  `likes_sent` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'количество поставленных лайков',
  `likes_mutual` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'количество взаимных лайков',
  PRIMARY KEY (`id`));

ALTER TABLE `social_network`.`user` 
ADD INDEX `idx_user_name` (`name` ASC) VISIBLE;
;

--Таблица для хранения лайков пользователям

CREATE TABLE `social_network`.`user_likes` (
  `sender` INT UNSIGNED NOT NULL,
  `receiver` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`sender`, `receiver`),
  INDEX `fk_ul_receiver_user_id_idx` (`receiver` ASC) VISIBLE,
  CONSTRAINT `fk_ul_sender_user_id`
    FOREIGN KEY (`sender`)
    REFERENCES `social_network`.`user` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT `fk_ul_receiver_user_id`
    FOREIGN KEY (`receiver`)
    REFERENCES `social_network`.`user` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT);

--Вспомогательная таблица-очередь для расчета количества лайков

CREATE TABLE `social_network`.`user_likes_queue` (
  `sender` INT UNSIGNED NOT NULL,
  `receiver` INT UNSIGNED NOT NULL,
  `timestamp` TIMESTAMP NOT NULL,
  PRIMARY KEY (`sender`, `receiver`));


--Проставление лайка:
--В одной транзакции выполняется:
--1. INSERT в таблицу user_likes
--2. Увеличение на единицу значения в поле likes_sent таблицы user для пользователя, поставившего лайк. 
--Это увеличение выполняем в данной транзакции, т.к. проблем с блокировками она в себе не несет, а для 
--пользователя необходимо видеть результат своего действия сразу же (поставил лайк-счетчик увеличился)
--3. INSERT в таблицу user_likes_queue

--Пересчет количества полученных лайков и взаимных лайков происходит отложенно. Для этого с какой-то периодичностью, 
--например раз в минуту, вызывается процедура update_likes_count, которая обрабатывает очередь накопившихся за эту минуту лайков (user_likes_queue).

USE `social_network`;
DROP procedure IF EXISTS `update_likes_count`;

DELIMITER $$
USE `social_network`$$
CREATE DEFINER=`root`@`localhost` PROCEDURE `update_likes_count`()
BEGIN
  DECLARE done INT DEFAULT FALSE;
  DECLARE vSender INT;
  DECLARE vReceiver INT;
  DECLARE vCount INT;
  DECLARE cur CURSOR FOR SELECT sender, receiver FROM social_network.user_likes_queue order by `timestamp`;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  OPEN cur;

  read_loop: LOOP
    FETCH cur INTO vSender, vReceiver;
    IF done THEN
      LEAVE read_loop;
    END IF;
    START TRANSACTION; 
    SELECT count(*) INTO vCount FROM social_network.user_likes WHERE sender = vReceiver AND receiver = vSender;
    IF vCount = 1 THEN
    UPDATE social_network.`user` SET likes_mutual = likes_mutual + 1 WHERE id = vSender;
	UPDATE social_network.`user` SET likes_mutual = likes_mutual + 1, likes_received = likes_received + 1 WHERE id = vReceiver;
    END IF;
    IF vCount = 0 THEN
	UPDATE social_network.`user` SET likes_received = likes_received + 1 WHERE id = vReceiver;
    END IF;
    DELETE FROM social_network.user_likes_queue WHERE sender = vSender AND receiver = vReceiver;
    COMMIT;
  END LOOP;

  CLOSE cur;
END$$

DELIMITER ;


--Запрос, который выведет информацию id пользователя, имя, лайков получено, лайков поставлено, взаимные лайки:
select * from social_network.`user` where id = 1;

--Список всех пользователей, которые поставили лайк пользователям 1 и 2, но при этом не поставили лайк пользователю 3:
select l1.sender from social_network.user_likes l1 
where l1.receiver = 1 
and exists (select * from social_network.user_likes l2 where l2.sender = l1.sender and l2.receiver = 2)
and not exists (select * from social_network.user_likes l3 where l3.sender = l1.sender and l3.receiver = 3);

--Таблица с фотографиями. Число лайков хранится на фотографии, чтобы не пересчитывать постоянно это значение по таблице лайков и не создавать лишнюю нагрузку. 
--Увеличивается это значение при проставлении лайка фотографии в транзакции. Аалогично с числом лайков для комментариев.
CREATE TABLE `social_network`.`photo` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` INT UNSIGNED NOT NULL,
  `likes` INT UNSIGNED NOT NULL DEFAULT 0,
  `photo_url` VARCHAR(255) NULL, --сделала возможным null, т.к. предполагаю, что до загрузки фото будет добавлена запись в БД, получен id, далее уже загружено фото по url, связанному с id
  PRIMARY KEY (`id`),
  INDEX `fk_photo_user_id_idx` (`user_id` ASC) VISIBLE,
  CONSTRAINT `fk_photo_user_id`
    FOREIGN KEY (`user_id`)
    REFERENCES `social_network`.`user` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT);

--Таблица с комментариями:
CREATE TABLE `social_network`.`comment` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `photo_id` BIGINT UNSIGNED NOT NULL,
  `user_id` INT UNSIGNED NOT NULL COMMENT 'пользователь, оставивший комментарий',
  `comment` TEXT NOT NULL,
  `likes` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  INDEX `fk_comment_photo_id_idx` (`photo_id` ASC) VISIBLE,
  INDEX `fk_comment_user_id_idx` (`user_id` ASC) VISIBLE,
  CONSTRAINT `fk_comment_photo_id`
    FOREIGN KEY (`photo_id`)
    REFERENCES `social_network`.`photo` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT `fk_comment_user_id`
    FOREIGN KEY (`user_id`)
    REFERENCES `social_network`.`user` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT);

--таблица лайков фото. При отзыве лайка проставляется 0 в поле state. Можно было просто удалять строку при отзыве, но предположила, что таких случаев не должно быть слишком много, чтобы занимало много места, а информация может понадобиться, например, для статистики.
CREATE TABLE `social_network`.`photo_likes` (
  `photo_id` BIGINT UNSIGNED NOT NULL,
  `user_id` INT UNSIGNED NOT NULL,
  `state` TINYINT NOT NULL COMMENT '1 - лайк проставлен\n0 - лайк отозван',
  PRIMARY KEY (`photo_id`, `user_id`),
  INDEX `fk_photo_likes_user_id_idx` (`user_id` ASC) VISIBLE,
  CONSTRAINT `fk_photo_likes_photo_id`
    FOREIGN KEY (`photo_id`)
    REFERENCES `social_network`.`photo` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT `fk_photo_likes_user_id`
    FOREIGN KEY (`user_id`)
    REFERENCES `social_network`.`user` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT);

--таблица лайков комментариев. Аналогично при отзыве лайка проставляется 0 в поле state.
--Можно было хранить лайки фото и лайки комментариев в одной таблице, но решила не смешивать их, чтобы не усложнять поиск пользователей, лайкнувших сущность. 
--Что касается появления новых сущностей, то закладываться на это заранее, если нет конкретных требований, считаю неоптимальным
CREATE TABLE `social_network`.`comment_likes` (
  `comment_id` BIGINT UNSIGNED NOT NULL,
  `user_id` INT UNSIGNED NOT NULL,
  `state` TINYINT NOT NULL COMMENT '1 - лайк проставлен , 0 - лайк отозван',
  PRIMARY KEY (`comment_id`, `user_id`),
  INDEX `fk_comment_likes_user_id_idx` (`user_id` ASC) VISIBLE,
  CONSTRAINT `fk_comment_likes_comment_id`
    FOREIGN KEY (`comment_id`)
    REFERENCES `social_network`.`comment` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,
  CONSTRAINT `fk_comment_likes_user_id`
    FOREIGN KEY (`user_id`)
    REFERENCES `social_network`.`user` (`id`)
    ON DELETE RESTRICT
    ON UPDATE RESTRICT);
