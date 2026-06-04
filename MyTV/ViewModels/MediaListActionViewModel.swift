import Foundation

@Observable
@MainActor
final class MediaListActionViewModel {
    var lists: [TraktListDTO] = []
    var isLoadingLists = false
    var isLoadingMembership = false
    var isSubmitting = false
    var message: String?
    var errorMessage: String?
    var isInWatchlist = false
    var addedListIds: Set<Int> = []

    private var didLoadLists = false
    private var loadedMembershipTarget: MediaListTarget?
    private var username: String?

    var isLoggedIn: Bool { AuthService.shared.isLoggedIn }
    var hasJoinedList: Bool { isInWatchlist || !addedListIds.isEmpty }

    var actionTitle: String {
        if isSubmitting {
            return "处理中..."
        }
        if isLoadingMembership {
            return "检查中..."
        }
        return hasJoinedList ? "管理列表" : "加入列表"
    }

    var actionIcon: String {
        if isSubmitting || isLoadingMembership {
            return "hourglass"
        }
        return hasJoinedList ? "checkmark.circle.fill" : "text.badge.plus"
    }

    func loadListsIfNeeded() async {
        guard isLoggedIn, !didLoadLists, !isLoadingLists else { return }
        isLoadingLists = true
        defer { isLoadingLists = false }

        do {
            let profile = try await UserAPI.profile()
            username = profile.user.ids.slug
            lists = try await UserAPI.customLists(username: profile.user.ids.slug)
            didLoadLists = true
        } catch {
            errorMessage = message(for: error)
            print("加载自定义列表失败: \(error)")
        }
    }

    func loadStateIfNeeded(for target: MediaListTarget?) async {
        guard let target, isLoggedIn, loadedMembershipTarget != target, !isLoadingMembership else {
            if target != nil {
                await loadListsIfNeeded()
            }
            return
        }

        loadedMembershipTarget = target
        isLoadingMembership = true
        isInWatchlist = false
        addedListIds = []
        defer { isLoadingMembership = false }

        do {
            let username = try await currentUsername()
            let fetchedLists = try await UserAPI.customLists(username: username)
            lists = fetchedLists
            didLoadLists = true

            async let watchlistResult = ListAPI.watchlistItems(type: target.itemType)
            async let customListIdsResult = loadJoinedCustomListIds(
                target: target,
                username: username,
                lists: fetchedLists
            )

            let watchlistItems = try await watchlistResult
            isInWatchlist = watchlistItems.contains { target.matches($0) }
            addedListIds = await customListIdsResult
        } catch {
            errorMessage = message(for: error)
            print("加载列表状态失败: \(error)")
        }
    }

    func addToWatchlist(_ target: MediaListTarget) async {
        guard isLoggedIn else {
            errorMessage = "登录 Trakt 后才能加入观看清单"
            return
        }

        let didUpdate = await submit(
            successMessage: "\(target.successName)已加入观看清单",
            alreadyMessage: "\(target.successName)已在观看清单中"
        ) {
            switch target {
            case .movie(let id):
                _ = try await SyncAPI.addToWatchlist(movies: [id])
            case .show(let id):
                _ = try await SyncAPI.addToWatchlist(shows: [id])
            case .season(let id):
                _ = try await SyncAPI.addToWatchlist(seasons: [id])
            case .episode(let id):
                _ = try await SyncAPI.addToWatchlist(episodes: [id])
            }
            CacheService.clearAPIResponses(containing: "user_watchlist")
            CacheService.clearAPIResponses(containing: "watchlist_items_")
            CacheService.clearAPIResponses(containing: "up_next")
        }
        if didUpdate {
            isInWatchlist = true
        }
    }

    func removeFromWatchlist(_ target: MediaListTarget) async {
        guard isLoggedIn else {
            errorMessage = "登录 Trakt 后才能修改观看清单"
            return
        }

        let didUpdate = await submit(
            successMessage: "\(target.successName)已从观看清单移除",
            notFoundMessage: "\(target.successName)已不在观看清单中"
        ) {
            switch target {
            case .movie(let id):
                _ = try await SyncAPI.removeFromWatchlist(movies: [id])
            case .show(let id):
                _ = try await SyncAPI.removeFromWatchlist(shows: [id])
            case .season(let id):
                _ = try await SyncAPI.removeFromWatchlist(seasons: [id])
            case .episode(let id):
                _ = try await SyncAPI.removeFromWatchlist(episodes: [id])
            }
            CacheService.clearAPIResponses(containing: "user_watchlist")
            CacheService.clearAPIResponses(containing: "watchlist_items_")
            CacheService.clearAPIResponses(containing: "up_next")
        }
        if didUpdate {
            isInWatchlist = false
        }
    }

    func add(_ target: MediaListTarget, to list: TraktListDTO) async {
        guard isLoggedIn else {
            errorMessage = "登录 Trakt 后才能加入自定义列表"
            return
        }

        let didUpdate = await submit(
            successMessage: "\(target.successName)已加入「\(list.name)」",
            alreadyMessage: "\(target.successName)已在「\(list.name)」中"
        ) {
            let username = try await currentUsername()
            _ = try await ListAPI.addToList(
                username: username,
                listId: list.ids.trakt,
                target: target
            )
            CacheService.clearAPIResponses(containing: "user_lists")
            CacheService.clearAPIResponses(containing: "list_items_\(username)_\(list.ids.trakt)")
        }
        if didUpdate {
            addedListIds.insert(list.ids.trakt)
        }
    }

    func remove(_ target: MediaListTarget, from list: TraktListDTO) async {
        guard isLoggedIn else {
            errorMessage = "登录 Trakt 后才能修改自定义列表"
            return
        }

        let didUpdate = await submit(
            successMessage: "\(target.successName)已从「\(list.name)」移除",
            notFoundMessage: "\(target.successName)已不在「\(list.name)」中"
        ) {
            let username = try await currentUsername()
            _ = try await ListAPI.removeFromList(
                username: username,
                listId: list.ids.trakt,
                target: target
            )
            CacheService.clearAPIResponses(containing: "user_lists")
            CacheService.clearAPIResponses(containing: "list_items_\(username)_\(list.ids.trakt)")
        }
        if didUpdate {
            addedListIds.remove(list.ids.trakt)
        }
    }

    func toggle(_ target: MediaListTarget, in list: TraktListDTO) async {
        if isAdded(to: list) {
            await remove(target, from: list)
        } else {
            await add(target, to: list)
        }
    }

    @discardableResult
    func createListAndAdd(
        _ target: MediaListTarget,
        name: String,
        description: String?,
        privacy: String,
        displayNumbers: Bool,
        allowComments: Bool
    ) async -> Bool {
        guard isLoggedIn else {
            errorMessage = "登录 Trakt 后才能创建列表"
            return false
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "列表名称不能为空"
            return false
        }

        var createdListId: Int?
        let didUpdate = await submit(successMessage: "\(target.successName)已加入「\(trimmedName)」") {
            let username = try await currentUsername()
            let newList = try await ListAPI.createList(
                username: username,
                name: trimmedName,
                description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
                privacy: privacy,
                displayNumbers: displayNumbers,
                allowComments: allowComments
            )
            _ = try await ListAPI.addToList(
                username: username,
                listId: newList.ids.trakt,
                target: target
            )
            lists.insert(newList, at: 0)
            createdListId = newList.ids.trakt
            didLoadLists = true
            CacheService.clearAPIResponses(containing: "user_lists")
            CacheService.clearAPIResponses(containing: "list_items_\(username)_\(newList.ids.trakt)")
        }
        if didUpdate, let createdListId {
            addedListIds.insert(createdListId)
        }
        return didUpdate
    }

    func isAdded(to list: TraktListDTO) -> Bool {
        addedListIds.contains(list.ids.trakt)
    }

    @discardableResult
    private func submit(
        successMessage: String,
        alreadyMessage: String? = nil,
        notFoundMessage: String? = nil,
        operation: () async throws -> Void
    ) async -> Bool {
        guard !isSubmitting else { return false }
        isSubmitting = true
        message = nil
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await operation()
            message = successMessage
            return true
        } catch {
            if isConflict(error), let alreadyMessage {
                message = alreadyMessage
                return true
            }
            if isNotFound(error), let notFoundMessage {
                message = notFoundMessage
                return true
            }
            errorMessage = message(for: error)
            print("列表操作失败: \(error)")
            return false
        }
    }

    private func currentUsername() async throws -> String {
        if let username {
            return username
        }
        let profile = try await UserAPI.profile()
        username = profile.user.ids.slug
        return profile.user.ids.slug
    }

    private func loadJoinedCustomListIds(
        target: MediaListTarget,
        username: String,
        lists: [TraktListDTO]
    ) async -> Set<Int> {
        await withTaskGroup(of: Int?.self, returning: Set<Int>.self) { group in
            for list in lists {
                group.addTask {
                    do {
                        let items = try await ListAPI.items(
                            username: username,
                            listId: list.ids.trakt,
                            type: target.itemType
                        )
                        return items.contains { target.matches($0) } ? list.ids.trakt : nil
                    } catch {
                        print("加载自定义列表条目失败: \(error)")
                        return nil
                    }
                }
            }

            var result = Set<Int>()
            for await listId in group {
                if let listId {
                    result.insert(listId)
                }
            }
            return result
        }
    }

    private func isConflict(_ error: Error) -> Bool {
        if case APIError.httpError(let statusCode, _) = error, statusCode == 409 {
            return true
        }
        return false
    }

    private func isNotFound(_ error: Error) -> Bool {
        if case APIError.httpError(let statusCode, _) = error, statusCode == 404 {
            return true
        }
        return false
    }

    private func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized, .refreshTokenFailed:
                return "登录状态已过期，请重新登录 Trakt"
            case .httpError(let statusCode, _):
                switch statusCode {
                case 401: return "登录 Trakt 后才能修改列表"
                case 404: return "没有找到这个列表或条目"
                case 409: return "这个条目已经在列表里"
                default: return "Trakt 返回错误 \(statusCode)"
                }
            default:
                return apiError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
