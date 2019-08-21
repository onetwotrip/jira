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
      jira  = JIRA::Client.new SimpleConfig.jira.to_h
      issue = jira.Issue.find(SimpleConfig.jira.issue)
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Запущено подтягивание мастеров в ветки задачи(!)
        Ожидайте сообщение о завершении
      {panel}
      BODY
      begin
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
          with repo_path do
            checkout branch['name']
            pull('origin', branch['name'])
            pull('origin', 'master')
            push(repo_path.remote('origin'), branch['name'])
          end
        end
      rescue StandardError => e
        issue.post_comment <<-BODY
        {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
         Не удалось подтянуть мастера (x)
         Подробности в логе таски https://jenkins.twiket.com/view/RELEASE/job/merge_master/
        {panel}
        BODY
        LOGGER.error "Не подтянуть мастера, ошибка: #{e.message}, трейс:\n\t#{e.backtrace.join("\n\t")}"
        issue.transition 'Merge Fail'
        exit(1)
      end
      issue.post_comment <<-BODY
      {panel:title=Release notify!|borderStyle=dashed|borderColor=#ccc|titleBGColor=#E5A443|bgColor=#F1F3F1}
        Ветки обновлены! (/)
      {panel}
      BODY
    end
  end
end
