function Linemode:all()
	local file = self._file
	local perm = file.cha:perm() or ""
	local user = ya.user_name and ya.user_name(file.cha.uid) or file.cha.uid
	local group = ya.group_name and ya.group_name(file.cha.gid) or file.cha.gid
	local owner = string.format("%s:%s", user, group)
	local sz = file:size()
	local size = sz and ya.readable_size(sz) or ""
	local t = math.floor(file.cha.mtime or 0)
	local mtime = t == 0 and "" or (os.date("%Y", t) == os.date("%Y") and os.date("%m/%d %H:%M", t) or os.date("%m/%d  %Y", t))
	return string.format("%s %s %s %s", perm, owner, size, mtime)
end
