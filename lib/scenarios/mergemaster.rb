module Scenarios
  ##
  # Merge masters to branches
  class MergeMaster
    def with(instance, &block)
      instance.instance_eval(&block)
      instance
    end

    def run
      LOGGER.info "Starting merge_master for #{SimpleConfig.jira.issue}"
      jira       = JIRA::Client.new SimpleConfig.jira.to_h
      issue      = jira.Issue.find(SimpleConfig.jira.issue)
      fail_merge = {}
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущено подтягивание мастеров в ветки задачи(!)
        Ожидайте сообщение о завершении
      {panel}
      BODY

      issue.related['branches'].each do |branch|
        LOGGER.info "Start work with branch: #{branch['name']}"
        repo_path = git_repo(branch['repository']['url'])
        # Prepare repo
        repo_path.checkout('master')
        repo_path.pull
        repo_path.chdir do
          `git fetch --prune`
        end
        # Check for case when branch has correct name, but was deleted from issue
        unless repo_path.is_branch? branch['name']
          LOGGER.error "[SKIP] #{branch['repository']['name']}/#{branch['name']} - branch doesn't exist"
          next
        end
        begin
          with repo_path do
            checkout branch['name']
            pull('origin', branch['name'])
            pull('origin', 'master')
            push(repo_path.remote('origin'), branch['name'])
          end
        rescue StandardError => e
          LOGGER.error "Не подтянуть мастера, ошибка: #{e.message}, трейс:\n\t#{e.backtrace.join("\n\t")}"
          fail_merge[branch['repository']['name'].to_sym] = branch['name']
        end
      end
      if fail_merge.empty?
        issue.post_comment <<-BODY
        {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
          Ветки обновлены! (/)
        {panel}
        BODY
      else
        issue.post_comment <<-BODY
            {panel:title=Build status error|borderStyle=dashed|borderColor=#ccc|titleBGColor=#F7D6C1|bgColor=#FFFFCE}
               Не удалось подтянуть мастера (x)
                *Причина:* Merge conflict
                *Ветки:* #{fail_merge}
            {panel}
        BODY
      end
    end
  end
end
