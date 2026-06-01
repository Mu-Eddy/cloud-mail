import orm from '../entity/orm';
import perm from '../entity/perm';
import { eq, ne, and, asc } from 'drizzle-orm';
import rolePerm from '../entity/role-perm';
import user from '../entity/user';
import role from '../entity/role';
import { permConst } from '../const/entity-const';
import { t } from '../i18n/i18n'

const avatarPerms = [
	{ name: '邮箱头像修改', permKey: 'account:set-avatar', pid: 21, type: 2, sort: 3 },
	{ name: '用户邮箱头像修改', permKey: 'user:set-account-avatar', pid: 6, type: 2, sort: 8 }
];

export async function ensureAvatarPerms(c) {
	const promises = avatarPerms.map(item => c.env.db.prepare(`
		INSERT INTO perm (name, perm_key, pid, type, sort)
		SELECT ?, ?, ?, ?, ?
		WHERE NOT EXISTS (SELECT 1 FROM perm WHERE perm_key = ?)
	`).bind(item.name, item.permKey, item.pid, item.type, item.sort, item.permKey).run());

	await Promise.all(promises);
}

const permService = {
	async tree(c) {
		await ensureAvatarPerms(c);

		const pList = await orm(c).select().from(perm).where(eq(perm.pid, 0)).orderBy(asc(perm.sort)).all();
		const cList = await orm(c).select().from(perm).where(ne(perm.pid, 0)).orderBy(asc(perm.sort)).all();

		cList.forEach(cItem => {
			cItem.name = t('perms.' + cItem.name)
		})

		pList.forEach(pItem => {
			pItem.name = t('perms.' + pItem.name)
			pItem.children = cList.filter(cItem => cItem.pid === pItem.permId)
		})
		return pList;
	},

	async userPermKeys(c, userId) {
		const userPerms = await orm(c).select({permKey: perm.permKey}).from(user)
			.leftJoin(role, eq(role.roleId,user.type))
			.rightJoin(rolePerm, eq(rolePerm.roleId,role.roleId))
			.leftJoin(perm, eq(rolePerm.permId,perm.permId))
			.where(and(eq(user.userId,userId),eq(perm.type,permConst.type.BUTTON)))
			.all();
		return userPerms.map(perm => perm.permKey);
	}
}

export default permService
