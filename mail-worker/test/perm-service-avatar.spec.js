import { beforeEach, describe, expect, it, vi } from 'vitest';

const { prepare, bind, run, select } = vi.hoisted(() => ({
	prepare: vi.fn(),
	bind: vi.fn(),
	run: vi.fn(),
	select: vi.fn()
}));

vi.mock('../src/entity/orm.js', () => ({
	default: () => ({
		select
	})
}));

vi.mock('../src/i18n/i18n.js', () => ({
	t: (key) => key.replace('perms.', '')
}));

function query(rows) {
	return {
		from() {
			return this;
		},
		where() {
			return this;
		},
		orderBy() {
			return {
				all: vi.fn().mockResolvedValue(rows)
			};
		}
	};
}

describe('perm service avatar permissions', () => {
	let permService;
	const c = { env: { db: { prepare } } };

	beforeEach(async () => {
		vi.clearAllMocks();
		run.mockResolvedValue();
		bind.mockReturnValue({ run });
		prepare.mockReturnValue({ bind });
		select
			.mockReturnValueOnce(query([{ permId: 21, name: '邮箱侧栏' }]))
			.mockReturnValueOnce(query([
				{ permId: 101, name: '邮箱头像修改', permKey: 'account:set-avatar', pid: 21, type: 2, sort: 3 },
				{ permId: 102, name: '用户邮箱头像修改', permKey: 'user:set-account-avatar', pid: 6, type: 2, sort: 8 }
			]));
		permService = (await import('../src/service/perm-service.js')).default;
	});

	it('ensures avatar permissions exist before returning the role tree', async () => {
		const tree = await permService.tree(c);

		expect(prepare).toHaveBeenCalledTimes(2);
		expect(bind).toHaveBeenCalledWith('邮箱头像修改', 'account:set-avatar', 21, 2, 3, 'account:set-avatar');
		expect(bind).toHaveBeenCalledWith('用户邮箱头像修改', 'user:set-account-avatar', 6, 2, 8, 'user:set-account-avatar');
		expect(run).toHaveBeenCalledTimes(2);
		expect(tree[0].children.map(item => item.permKey)).toContain('account:set-avatar');
	});
});
